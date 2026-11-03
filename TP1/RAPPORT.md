# TP1 — Configuration avancée du système Linux



## 1. Présentation de l'environnement



Ce TP a été réalisé avec deux machines virtuelles sous **Rocky Linux 9.8**, hébergées dans VirtualBox.



| Machine | Rôle |

|---|---|

| `srv-core` | Serveur principal : collecte de télémétrie, archivage et configuration réseau |

| `srv-edge` | Serveur secondaire : communication réseau et VLAN |



Les manipulations ont été réalisées avec les outils `systemd`, `NetworkManager`, `iproute2`, `tcpdump`, `cron` et des scripts Bash.



Les fichiers de configuration sont conservés dans `TP1/configs/` et les preuves d'exécution dans `TP1/captures/`.



\---



## 2. Mission 1 — Gestion avancée de systemd



### 2.1 Analyse du démarrage

L'analyse du démarrage de `srv-core` a été réalisée avant et après les optimisations à l'aide de `systemd-analyze` et de la représentation graphique `systemd-analyze plot`.

Les mesures obtenues sont les suivantes :

| Phase | Avant optimisation | Après optimisation |
|---|---:|---:|
| Kernel | 1,625 s | 2,113 s |
| Initrd | 2,959 s | 5,227 s |
| Userspace | 65,850 s | 4,823 s |
| **Temps total** | **70,434 s** | **12,164 s** |
| Atteinte de `multi-user.target` | 63,561 s | 2,604 s |

Le temps total de démarrage est passé de 70,434 secondes à 12,164 secondes, soit un gain de 58,270 secondes, correspondant à une réduction d'environ **82,7 %**.

Les modifications réalisées comprennent notamment la désactivation temporaire de `firewalld` et le masquage de `NetworkManager-wait-online.service`.

La comparaison montre une diminution importante du temps passé dans l'espace utilisateur. Les durées du noyau et de l'initrd ont toutefois légèrement augmenté ; le gain global provient principalement de la réduction du temps userspace.

Les commandes `systemd-analyze blame` et `systemd-analyze critical-chain` ont également été utilisées pour identifier les unités et dépendances impliquées dans le démarrage.


### 2.2 Service de collecte Helios



Un script Bash `/usr/local/sbin/helios-collect.sh` a été créé pour collecter périodiquement des informations système.



Les données enregistrées comprennent :

\- La date et l'heure de collecte.

\- La charge système.

\- La mémoire disponible.



Les données sont enregistrées au format CSV dans :



```text

/var/lib/helios/telemetry.csv

```



Un compte système dédié `helios`, sans connexion interactive, a été créé pour exécuter le service.



Le service `helios-collect.service` est configuré avec systemd. Un fichier complémentaire `override.conf` permet d'ajuster les ressources :



| Paramètre | Valeur |

|---|---:|

| Intervalle de collecte | 5 secondes |

| CPUQuota | 20 % |

| MemoryMax | 96 Mo |

| IOWeight | 50 |

| Nice | 5 |



Le service a été démarré et son fonctionnement vérifié avec `systemctl status`. Les nouvelles lignes ont été observées dans le fichier CSV.



La commande d'exécution du script utilise explicitement Bash afin d'éviter le problème d'exécution rencontré initialement :



```ini

ExecStart=/usr/bin/bash /usr/local/sbin/helios-collect.sh

```



### 2.3 Gestion des processus



Les commandes `nice`, `renice` et `ionice` ont été utilisées pour observer et modifier les priorités d'un processus de test.



Un processus `sha256sum` a été lancé avec une priorité CPU faible :



```bash

nice -n 19 sha256sum /dev/zero \&

```



Sa priorité a ensuite été modifiée :



```bash

renice -n 5 -p PID

ionice -c 2 -n 7 -p PID

```



La commande `ps` a permis de vérifier la valeur de nice et `ionice` la classe et la priorité d'E/S.



### 2.4 Target Helios



Une cible personnalisée `helios.target` a été créée pour regrouper les composants de l'application Helios.



Le service de collecte a été associé à cette cible avec :



```bash

systemctl add-wants helios.target helios-collect.service

systemctl enable helios.target

```



L'état de la cible a été vérifié avec `systemctl is-enabled` et `systemctl is-active`. La liste des dépendances a été consultée avec :



```bash

systemctl list-dependencies helios.target

```



\---



## 3. Mission 2 — Configuration réseau avancée



### 3.1 Bonding actif/passif



Sur `srv-core`, deux interfaces réseau internes, `enp0s9` et `enp0s10`, ont été regroupées dans une interface logique `bond0`.



Le mode utilisé est **active-backup**, adapté à l'environnement VirtualBox qui ne permet pas de reproduire le scénario LACP demandé.



Configuration principale :

\- Interface logique : `bond0`

\- Adresse IPv4 : `10.42.0.10/24`

\- Interface principale : `enp0s9`

\- Interface secondaire : `enp0s10`

\- Mode : `active-backup`

\- Surveillance du lien : `miimon=100`

\- `fail\_over\_mac=active`



Sur `srv-edge`, l'interface `enp0s9` utilise l'adresse `10.42.0.11/24`.



La communication entre les deux machines a été vérifiée par ping.



### 3.2 Test de bascule



La bascule a été testée en désactivant temporairement le lien VirtualBox correspondant à `enp0s9` sur `srv-core`.



La commande utilisée depuis l'hôte était :



```bash

VBoxManage controlvm "srv-core" setlinkstate3 off

```



Le fichier `/proc/net/bonding/bond0` a montré que l'interface active est passée de `enp0s9` à `enp0s10`.



Après réactivation du lien :



```bash

VBoxManage controlvm "srv-core" setlinkstate3 on

```



l'interface principale `enp0s9` est redevenue active.



Le test confirme le fonctionnement du mécanisme de redondance active/passive.



### 3.3 Configuration du VLAN 42



Un VLAN identifié par le numéro **42** a été configuré sur les deux machines.



| Machine | Interface VLAN | Adresse IPv4 |

|---|---|---|

| `srv-core` | `bond0.42` | `10.42.42.10/24` |

| `srv-edge` | `enp0s9.42` | `10.42.42.11/24` |



La communication entre les deux interfaces VLAN a été vérifiée.



Une capture réseau a été réalisée avec :



```bash

tcpdump -eni bond0 vlan 42

```



La capture a permis d'observer des trames 802.1Q portant l'identifiant VLAN 42, notamment des échanges ARP et ICMP.



Le fichier de capture est conservé dans `TP1/captures/vlan42.pcap`.



### 3.4 Routage par politique



Une table de routage personnalisée nommée `transport`, identifiée par le numéro **142**, a été ajoutée dans `/etc/iproute2/rt\_tables`.



Une route par défaut a été configurée dans cette table via `10.42.42.11`.



Une règle de routage a ensuite été créée pour les paquets ayant pour adresse source `10.42.42.10`, avec une priorité de 100.



La configuration a été rendue persistante avec NetworkManager.



Après redémarrage de la machine, les vérifications ont confirmé la présence de la règle et de la route :



```text

100: from 10.42.42.10 lookup transport proto static

default via 10.42.42.11 dev bond0.42 proto static metric 400

```



La commande :



```bash

ip route get 8.8.8.8 from 10.42.42.10

```



a confirmé l'utilisation de la table `transport` et de la passerelle `10.42.42.11`.



Une recherche de route sans adresse source spécifique a, quant à elle, utilisé la route principale via `10.0.2.2` sur `enp0s3`.



Ces résultats confirment la persistance et le fonctionnement du routage par politique.



\---



## 4. Mission 3 — Automatisation et archivage



### 4.1 Script d'archivage



Le script `/usr/local/sbin/helios-archive.sh` a été créé pour archiver les données de télémétrie.



Il utilise notamment :

\- `set -euo pipefail` pour renforcer la gestion des erreurs.

\- `flock` pour empêcher deux exécutions simultanées.

\- `gzip` pour compresser les archives.

\- `logger` pour enregistrer les événements dans le journal système.

\- `find` pour supprimer les archives dépassant la durée de conservation.



Les fichiers sources sont lus depuis :



```text

/var/lib/helios/telemetry.csv

```



Les archives compressées sont stockées dans :



```text

/var/lib/helios/archives/

```



La durée de conservation est fixée à 14 jours.



Le script crée une archive horodatée, vide ensuite le fichier source et conserve les archives avec les permissions et le propriétaire prévus.



### 4.2 Codes de retour et tests



Les codes de retour prévus sont :



| Code | Signification |

|---:|---|

| 0 | Exécution réussie |

| 1 | Erreur interne |

| 2 | Verrou déjà utilisé |

| 3 | Prérequis manquant |



Les tests réalisés ont permis de vérifier les comportements suivants :



\- Exécution normale : code retour 0 et création d'une archive compressée.

\- Verrou déjà pris : code retour 2.

\- Fichier source indisponible : code retour 3.



Après le test du fichier source manquant, le fichier a été restauré et le service de collecte redémarré.



Les archives produites ont été vérifiées dans le répertoire de destination. Les journaux ont également été consultés avec `journalctl`.



### 4.3 Service systemd



Un service `helios-archive.service` de type `oneshot` a été créé pour exécuter le script.



Il utilise notamment :

\- `Nice=10`

\- `IOSchedulingClass=idle`

\- `ConditionPathExists` pour vérifier la présence du fichier source.



Une exécution manuelle avec `systemctl start helios-archive.service` s'est terminée avec le statut `0/SUCCESS`.



L'état `inactive (dead)` affiché après l'exécution est normal pour un service de type `oneshot` qui a terminé son travail.



### 4.4 Timer systemd



Un timer `helios-archive.timer` a été configuré pour déclencher l'archivage chaque jour à 02 h 30.



Les paramètres principaux sont :



```ini

OnCalendar=*-*-* 02:30:00

AccuracySec=1min

RandomizedDelaySec=120

Persistent=yes

```



Le paramètre `RandomizedDelaySec` permet de répartir les déclenchements dans le temps. `Persistent=yes` permet de prendre en compte une échéance manquée pendant l'arrêt de la machine.



Le timer a été activé avec :



```bash

systemctl enable --now helios-archive.timer

```



Son état `active (waiting)` et sa prochaine échéance ont été vérifiés avec :



```bash

systemctl list-timers helios-archive.timer --all

```



### 4.5 Comparaison avec cron



Le paquet `cronie` a été installé et le service `crond` activé.



Une entrée temporaire a été créée dans `/etc/cron.d/helios-legacy` pour comparer le déclenchement quotidien avec cron :



```cron

MAILTO=""

30 2 * * * root /usr/local/sbin/helios-archive.sh

```



| Critère | Timer systemd | Cron |

|---|---|---|

| Planification | `OnCalendar` | Expression cron |

| Retard aléatoire | `RandomizedDelaySec` | Non configuré ici |

| Rattrapage après arrêt | `Persistent=yes` | Non fourni par cette entrée cron standard |

| Consultation | `systemctl list-timers` | Fichier cron |

| Journaux | Journal systemd | Journaux cron/syslog |

| Dépendances et conditions | Intégrées à systemd | À gérer séparément |



Le timer systemd apporte une meilleure intégration avec les unités, leurs dépendances et leurs journaux.



\---



## 5. Difficultés rencontrées et solutions



Plusieurs difficultés techniques ont été rencontrées pendant le TP.



\- **Exécution du script de collecte :** une erreur `203/EXEC` a été corrigée en faisant appel explicitement à `/usr/bin/bash` dans `ExecStart`.

\- **Création du drop-in systemd :** le répertoire de configuration complémentaire a dû être créé manuellement avant l'ajout de `override.conf`.

\- **Bascule réseau :** le mode active-backup a été retenu car VirtualBox ne permettait pas de reproduire le scénario LACP.

\- **Routage par politique :** une règle temporaire en doublon a été supprimée avant le redémarrage afin de vérifier la configuration persistante.

\- **Archivage :** les codes de retour 0, 2 et 3 ont été testés et validés.

\- **Transfert des preuves :** les fichiers ont été transférés des machines virtuelles vers le dépôt Windows avec SCP.



\---



## 6. Inventaire des fichiers livrés



### Configurations — `TP1/configs/`



| Fichier | Description |

|---|---|

| `helios-collect.sh` | Script de collecte |

| `helios-collect.service` | Service systemd de collecte |

| `override.conf` | Paramètres complémentaires du service |

| `helios.target` | Cible applicative Helios |

| `helios-archive.sh` | Script d'archivage |

| `helios-archive.service` | Service systemd d'archivage |

| `helios-archive.timer` | Planification quotidienne |



### Preuves — `TP1/captures/`



Les fichiers présents comprennent :

\- Les mesures de démarrage (`boot-summary.txt`, `boot-blame.txt`, `boot-critical-chain.txt`).

\- Les informations sur le bonding et les interfaces réseau.

\- Les règles et tables de routage.

\- Les informations sur le VLAN 42 et la capture `vlan42.pcap`.

\- L'état du timer et du service d'archivage.

\- Les journaux du script d'archivage.



\---



## 7. Conclusion



Ce TP a permis de mettre en œuvre plusieurs mécanismes avancés d'administration Linux sous Rocky Linux 9.8.



La première mission a permis de créer et gérer des services systemd, de contrôler les ressources et de regrouper les composants dans une cible dédiée.



La deuxième mission a permis de mettre en place une architecture réseau redondante avec bonding active-backup, un VLAN 42 et du routage par politique persistant.



La troisième mission a permis d'automatiser la sauvegarde des données de télémétrie grâce à un script Bash, un service systemd et un timer quotidien, puis de comparer cette solution avec cron.



Les configurations et les résultats des tests sont conservés dans les répertoires `configs` et `captures` afin de faciliter leur vérification.

