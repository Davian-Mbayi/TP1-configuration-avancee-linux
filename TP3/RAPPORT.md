# TP3 — Sécurisation d'un serveur Linux

**Module :** Administration Linux Server  
**Environnement :** Rocky Linux 9.8 — `srv-core` (serveur cible) et `srv-edge` (poste distant de test)  
**Dépôt :** TP1-configuration-avancee-linux

## 1. Objectifs

Ce TP met en place une défense en profondeur sur `srv-core` : segmentation du pare-feu, durcissement du service SSH, journalisation persistante, audit des actions sensibles et détection automatisée des échecs d'authentification SSH.

## 2. Mission 1 — Segmentation Firewalld

### 2.1 Affectation des interfaces aux zones

| Interface | Rôle | Zone Firewalld | Politique |
|---|---|---|---|
| `enp0s3` | NAT / accès Internet | `drop` | Trafic entrant non sollicité rejeté |
| `enp0s8` | Administration | `work` | SSH autorisé depuis le réseau d'administration `192.168.56.0/24`, avec journalisation et limitation de débit |
| `bond0` | Réseau métier | `internal` | SSH et supervision autorisés |
| `bond0.42` | VLAN transport | `internal` | SSH et supervision autorisés |

La zone par défaut est `drop`. Les zones et leurs règles effectives sont consignées dans `configs/zones.txt`.

### 2.2 Règles complémentaires

- Le service SSH standard a été retiré des règles simples et remplacé sur la zone d'administration par une règle riche journalisée avec le préfixe `SSH-NEW` et une limitation de débit.
- Le port TCP `10051` est rejeté depuis la zone `work` et autorisé dans la zone `internal` pour la supervision.
- L'ipset `helios-blacklist` permet de bloquer les adresses IP identifiées comme sources d'échecs répétés.
- La journalisation des paquets rejetés a été activée avec `firewall-cmd --set-log-denied=unicast`.

**Justification :** le trafic entrant est limité selon le rôle de chaque interface. L'administration est séparée du réseau métier et du VLAN transport. La zone `drop` réduit l'exposition de l'interface NAT.

## 3. Mission 2 — Durcissement SSH

### 3.1 Écoute et accès

Le service SSH est configuré sur le port TCP `2242`, en IPv4, sur les adresses d'administration et métier : `192.168.56.10` et `10.42.0.10`. L'accès direct de root est interdit. L'authentification par mot de passe et l'authentification interactive sont désactivées ; l'authentification par clé publique est exigée.

Le groupe `ssh-admins` restreint les comptes pouvant ouvrir une session. Le compte `sysops` sert à la connexion distante et au transfert de fichiers, sans droit sudo. Les opérations d'administration sont effectuées depuis la console root de la VM.

### 3.2 Réduction de la surface d'attaque

Les redirections X11, agent, TCP, socket Unix et tunnel générique sont désactivées par défaut. Une exception contrôlée autorise le groupe `helios-ops` à établir un transfert TCP vers `localhost:10051`.

Les paramètres de limitation incluent notamment `MaxAuthTries 3`, `MaxSessions 4`, `MaxStartups 10:30:60` et `LoginGraceTime 30`. Les connexions sont journalisées avec `LogLevel VERBOSE` et un bandeau d'avertissement est fourni par `/etc/issue.net`.

### 3.3 SELinux et pare-feu

Le port TCP `2242` a été déclaré au type SELinux `ssh_port_t` avec `semanage port`. Les règles Firewalld correspondantes ont été ajoutées aux zones `work` et `internal`, et l'ancien accès SSH sur le port `22` a été retiré.

### 3.4 Politique cryptographique

La politique système a été réglée sur `DEFAULT:NO-SHA1`. Les paramètres fournis par la politique cryptographique RHEL sont intégrés à la configuration effective d'OpenSSH. La commande `sshd -T` permet de vérifier les algorithmes réellement proposés après prise en compte des fichiers inclus.

Les valeurs relevées sont conservées dans `captures/crypto-policy.txt` et `captures/sshd-effective.txt`. La liste effective des MAC doit être examinée : le nom de politique `NO-SHA1` ne suffit pas, à lui seul, à prouver que chaque variante HMAC-SHA1 est absente. Aucun fichier de surcharge `05-helios-crypto.conf` n'est fourni dans ce rendu.

### 3.5 Conséquences d'un changement de port SSH sous RHEL 9

1. **OpenSSH :** `sshd_config` ou un fichier de surcharge doit déclarer le nouveau port, puis la syntaxe doit être validée avec `sshd -t` et le service rechargé ou redémarré.
2. **SELinux :** le port non standard doit être associé au type `ssh_port_t` avec `semanage port`, faute de quoi SELinux peut empêcher `sshd` de s'y attacher.
3. **Pare-feu et clients :** Firewalld doit autoriser le nouveau port et retirer l'ancien si nécessaire ; les clients, scripts, outils de supervision et règles de scan doivent également utiliser le nouveau port.

## 4. Mission 3 — Journalisation, audit et détection

### 4.1 Journald persistant

La configuration `/etc/systemd/journald.conf.d/50-helios.conf` active le stockage persistant, la compression, une limite d'usage de 500 Mo, un espace libre minimal de 1 Go, une taille maximale de fichier de 50 Mo, une rétention maximale d'un mois et une rotation quotidienne. Le contrôle des démarrages est enregistré dans `captures/journal-boots.txt`.

### 4.2 Investigation des journaux

Les requêtes suivantes permettent de répondre à des besoins distincts :

```bash
journalctl -u sshd.service --since '-2h' -p warning -o short-iso --no-pager
journalctl _SYSTEMD_UNIT=sshd.service -g 'Invalid user|Failed|Accepted' --no-pager
journalctl --facility=authpriv --since today --no-pager
journalctl _UID=5101 --since today --no-pager
journalctl -b -1 -p err --no-pager
```

- La première recherche les avertissements du service SSH sur une période récente.
- La deuxième isole les authentifications SSH acceptées ou refusées et les utilisateurs inexistants.
- La troisième rassemble les événements d'authentification et d'autorisation.
- La quatrième filtre les événements associés à l'UID `5101` (compte `nadia` dans l'environnement du TP).
- La cinquième recherche les erreurs du démarrage précédent, utile après un redémarrage ou une panne.

### 4.3 Auditd

Le fichier `configs/90-helios.rules` surveille les fichiers d'identité (`passwd`, `shadow`, `group`, `gshadow`), les règles sudo, la configuration SSH, le binaire setgid `/usr/local/bin/helios-lastlog`, les exécutions de commandes avec EUID 0 par des comptes humains et les modifications de Firewalld.

Les règles sont chargées avec `augenrules --load`. L'état du noyau se vérifie avec `auditctl -s` ; les événements se recherchent par clé avec `ausearch -k`. La vérification effectuée a montré `enabled 1` et `lost 0`.

### 4.4 Détection automatique des échecs SSH

Le script `configs/helios-watch-auth.sh` analyse les événements SSH des dix dernières minutes. Une adresse qui dépasse cinq événements d'échec est ajoutée à l'ipset `helios-blacklist`, à l'exception de l'adresse d'administration autorisée `192.168.56.1`. Les adresses déjà traitées sont conservées dans `/var/lib/helios/blocked.txt` pour éviter les ajouts répétés. Un verrou `flock` empêche les exécutions concurrentes.

Le service `helios-watch-auth.service` exécute le script et le timer `helios-watch-auth.timer` planifie son exécution toutes les deux minutes. Le test est réalisé depuis `srv-edge` en provoquant des échecs SSH avec un utilisateur inexistant, puis en vérifiant les journaux du script et les entrées de l'ipset.

## 5. Contrôles et preuves à joindre

Les éléments textuels exportés sont dans `captures/` et les configurations dans `configs/`. Ajouter les captures d'écran réelles suivantes avant remise :

- [ ] Scan Nmap avant durcissement.
- [ ] Scan Nmap après durcissement montrant le port `22` fermé et le port `2242` ouvert selon le point de scan.
- [ ] Tests SSH : connexion par clé, refus de root, refus d'authentification par mot de passe, refus de `nadia`, accès autorisé au compte prévu et contrôle de l'exception de tunnel.
- [ ] Traces noyau `SSH-NEW` et rejet du trafic interdit.
- [ ] Deux démarrages visibles dans `journalctl --list-boots`.
- [ ] Événements `ausearch` montrant les clés `sudoers`, `helios-setgid` et `privesc`.
- [ ] Adresse `192.168.56.11` visible dans l'ipset après la simulation d'échecs SSH.
- [ ] Timer `helios-watch-auth.timer` actif et en attente.

## 6. Fichiers remis

### `configs/`

- `zones.txt`
- `10-helios-hardening.conf`
- `issue.net`
- `50-helios.conf`
- `90-helios.rules`
- `helios-watch-auth.sh`
- `helios-watch-auth.service`
- `helios-watch-auth.timer`

### `captures/`

- `crypto-policy.txt`
- `sshd-effective.txt`
- `selinux-ssh-port.txt`
- `journal-boots.txt`
- `watch-auth.txt`
- `blacklist.txt`
- `audit-rules.txt`

