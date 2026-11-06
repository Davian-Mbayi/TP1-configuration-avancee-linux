# Projet Helios Suivi — Rapport de réalisation

**Système :** Rocky Linux 9.8  
**Serveur principal :** `srv-core`  
**Périmètre :** exigences E1 à E9

## 1. Gestion des comptes et des groupes — E1

Le groupe `suivi` et le compte `lea` ont été configurés. Le compte `lea` possède l'UID 5104 et appartient au groupe `suivi`.

Le compte technique `helios-suivi` utilise un shell non interactif (`/sbin/nologin`). La politique de mot de passe de `lea` prévoit une durée maximale de 90 jours et un avertissement 14 jours avant expiration.

**Résultat :** configuration vérifiée avec `getent`, `id` et `chage`.

Preuve : `preuves/E1.txt`.

## 2. Permissions et ACL — E2

Le répertoire `/srv/helios/suivi/www` appartient à `root:suivi` et dispose du bit SGID. Les ACL définissent les droits nécessaires pour les comptes et groupes concernés.

Le fichier `index.html` appartient à `lea:suivi`. Les permissions et ACL ont été vérifiées. Les tests d'accès non autorisés ont retourné « Permission denied », ce qui confirme le refus des accès concernés.

**Résultat :** permissions, héritage SGID et ACL vérifiés.

Preuve : `preuves/E2.txt`.

## 3. Publication des données JSON — E3

Le script de publication génère le fichier `etat.json` à partir des informations système et des mesures disponibles.

La publication a réussi avec un code retour 0. Le JSON contient notamment la date de génération, le nom de l'hôte, la charge système, la mémoire disponible et le nombre de mesures.

Un test avec l'utilisateur Nadia a été refusé avec le code retour attendu 3.

**Résultat :** publication fonctionnelle et contrôle d'accès testé.

Preuve : `preuves/E3.txt`.

## 4. Portail web et durcissement systemd — E4

Le service `helios-suivi.service` fonctionne avec l'utilisateur non privilégié `helios-suivi` et le groupe `suivi`.

Les principales limites configurées comprennent :
- Redémarrage automatique (`Restart=always`).
- Quota CPU de 50 %.
- Mémoire maximale de 128 Mio.
- Protections systemd, dont `ProtectSystem`, `ProtectHome`, `PrivateTmp` et `NoNewPrivileges`.

L'analyse `systemd-analyze security` donne un niveau d'exposition global de **1.4**.

Les tests HTTP de la page d'accueil et du fichier d'état ont retourné le code 200.


**Résultat :** portail accessible et service durci, avec les limites indiquées.

Preuve : `preuves/E4.txt`.

## 5. Délégation sudo — E5

Une règle dédiée a été installée dans `/etc/sudoers.d/92-helios-suivi`, avec les permissions `0440` et le propriétaire `root:root`.

L'utilisateur `lea` dispose uniquement des cinq commandes autorisées :
- Redémarrer `helios-suivi.service`.
- Consulter son état.
- Lancer `helios-suivi-publish.service`.
- Consulter les journaux du service.
- Consulter les journaux du service de publication.

La commande `sudo -l -U lea` confirme ces autorisations. Le redémarrage de `sshd` ne fait pas partie des droits accordés.

**Résultat :** délégation limitée vérifiée.

Preuve : `preuves/E5.txt`.

## 6. Pare-feu firewalld — E6

La zone par défaut est `drop`.

Les interfaces sont réparties entre les zones :
- `work` : interface d'administration `enp0s8`, source `192.168.56.0/24`.
- `internal` : interfaces `bond0` et `bond0.42`.
- Les autres interfaces indiquées dans la preuve restent dans la zone par défaut `drop`.


**Résultat :** segmentation et règles du pare-feu vérifiées.

Preuve : `preuves/E6.txt`.

## 7. Tests de non-régression sécurité — E7

Les contrôles confirment :
- SSH sur le port 2242.
- Connexion root SSH interdite.
- Authentification SSH par mot de passe désactivée.
- Accès SSH limité au groupe `ssh-admins`.
- Zone firewalld par défaut `drop`.
- Timer `helios-watch-auth.timer` actif.
- Répertoire `/var/log/journal` présent pour la persistance des journaux.

**Résultat :** contrôles de non-régression réalisés.

Preuve : `preuves/E7.txt`.

## 8. Supervision — E8

L'agent Zabbix 2 et le service sysstat sont actifs.

Les contrôles Zabbix retournent :
- `helios.suivi.http` : 200.
- `helios.suivi.age` : 93 secondes lors du relevé enregistré.

**Résultat :** agent actif et indicateurs de supervision fonctionnels.

Preuve : `preuves/E8.txt`.

## 9. Sauvegarde et restauration — E9

Le script de sauvegarde crée une archive des éléments du portail et de sa configuration. Une somme SHA-256 est générée pour vérifier l'intégrité de l'archive.

L'archive `suivi-20261105-173658.tar.gz` a passé le contrôle SHA-256. Le timer de sauvegarde est actif et activé au démarrage.

Un test de restauration dans un répertoire temporaire a permis de retrouver notamment `etat.json` et `index.html`.

**Résultat :** sauvegarde, intégrité et restauration vérifiées.

Preuve : `preuves/E9.txt`.

## 10. Conclusion

Les exigences E1 à E9 ont été réalisées et les résultats des contrôles sont consignés dans les fichiers de preuve correspondants du répertoire `preuves/`.
