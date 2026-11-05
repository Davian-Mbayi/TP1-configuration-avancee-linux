# TP2 — Gestion avancée des utilisateurs et des groupes



*Système :* Rocky Linux 9.8  

*Machine :* srv-core  

*Objectif :* Mettre en œuvre une politique avancée de gestion des comptes, des permissions, des ACL et des privilèges sudo.



## Mission 1 — Comptes, groupes et politique d'authentification



### Politique générale



Les paramètres suivants ont été appliqués dans `/etc/login.defs` :



| Paramètre | Valeur | Rôle |

|---|---:|---|

| PASS\_MAX\_DAYS | 90 | Durée maximale du mot de passe |

| PASS\_MIN\_DAYS | 1 | Délai minimal avant changement |

| PASS\_WARN\_AGE | 14 | Avertissement avant expiration |

| UMASK | 027 | Permissions par défaut restrictives |



La politique de complexité a été définie dans `50-helios.conf` : longueur minimale de 12 caractères, au moins trois classes de caractères, limitation des répétitions et vérification du dictionnaire et du nom utilisateur.



Le mécanisme `pam\_faillock` a été activé avec les paramètres suivants :

\- 5 échecs avant verrouillage ;

\- fenêtre de 900 secondes ;

\- verrouillage pendant 600 secondes ;

\- journalisation des échecs.



Le test d'un mot de passe trop court (`helios`) a été refusé. Le verrouillage du compte Nadia après cinq échecs a également été vérifié, puis réinitialisé.



### Groupes et utilisateurs



| Utilisateur | UID | Groupe principal | Groupes supplémentaires |

|---|---:|---|---|

| julien | 5100 | transport | helios-ops |

| nadia | 5101 | transport | — |

| tarek | 5102 | telemetry | transport |

| audit-ext | 5103 | telemetry | — |



Les groupes `transport`, `telemetry` et `helios-ops` utilisent respectivement les GID 5000, 5001 et 5002.



Le compte `audit-ext` possède une date d'expiration fixée à 21 jours après sa création.



Julien a été défini comme administrateur du groupe `transport` et a pu y ajouter Nadia.



## Mission 2 — Permissions spéciales et umask



### Setgid



Le répertoire `/srv/helios/projets/transport` possède les permissions `2770` et appartient à `julien:transport`.



Un fichier créé par Tarek dans ce répertoire hérite du groupe `transport`. Dans le répertoire témoin sans setgid, le fichier hérite du groupe principal `telemetry`.



### Sticky bit



Le répertoire `/srv/helios/depot` utilise le mode `1777`.



Nadia a créé un fichier que Tarek n'a pas pu supprimer. Tarek a cependant pu supprimer son propre fichier.



### Comparaison des umasks



| Umask | Fichier créé (0666) | Répertoire créé (0777) |

|---|---:|---:|

| 027 | 640 | 750 |

| 002 | 664 | 775 |

| 077 | 600 | 700 |



Le script `/etc/profile.d/helios-umask.sh` applique :

\- umask 002 aux membres du groupe `transport` ;

\- umask 027 aux autres utilisateurs.



### Inventaire SUID/SGID



L'inventaire a été réalisé avec :



`find / -xdev \\( -perm -4000 -o -perm -2000 \\) -type f`



Trois exemples de binaires et leur justification :



\- `/usr/bin/passwd` : SUID root nécessaire pour modifier les informations de mot de passe protégées.

\- `/usr/bin/su` : SUID root nécessaire pour effectuer le changement d'identité utilisateur.

\- `/usr/bin/sudo` : SUID root nécessaire pour exécuter les commandes autorisées avec des privilèges élevés.



Un script shell de test en mode 4755 a montré que le bit SUID n'est pas appliqué aux scripts interprétés.



### Binaire SGID Helios



Le programme `helios-lastlog` a été compilé depuis `helios-lastlog.c`, puis configuré avec le propriétaire `root:telemetry` et le mode `2755`.



Le fichier `/var/log/helios/app.log` appartient à `root:telemetry` et possède le mode `0640`.



Julien ne peut pas lire directement ce journal, mais peut utiliser le programme `helios-lastlog` pour consulter ses dix dernières lignes.



## Mission 3 — ACL



Le système de fichiers utilisé est XFS.



Une ACL récursive a accordé à `audit-ext` les droits de lecture et de traversée sur le projet transport, sans autorisation d'écriture.



Des ACL par défaut ont été définies pour les nouveaux fichiers et répertoires :

\- `audit-ext` : lecture ;

\- groupe `transport` : lecture, écriture et traversée ;

\- autres : aucun droit.



### Masque ACL et chmod



Une entrée ACL a accordé `rwx` à Tarek. Après `chmod g-w`, le masque ACL est devenu `r-x`.



L'entrée nominative de Tarek affichait alors `rwx`, mais ses droits effectifs étaient `r-x`. Il ne pouvait donc plus écrire dans le fichier.



La commande `setfacl -m m::rwx` a restauré les droits effectifs d'écriture.



### Sauvegarde et restauration



Les ACL ont été sauvegardées avec `getfacl -R`, supprimées avec `setfacl -Rb`, puis restaurées avec `setfacl --restore`.



La restauration a nécessité de se placer à la racine `/`, car les chemins de la sauvegarde étaient relatifs.



### Comparaison des copies et archivage



\- `cp -a` a conservé le propriétaire, les ACL étendues et les ACL par défaut.

\- `cp -r` n'a pas conservé ces informations dans le test réalisé.

\- Une archive `transport-acl.tar` a été créée avec `tar --acls --xattrs` pour préserver les ACL et attributs étendus.



## Mission 4 — Sudo avancé



Le fichier `/etc/sudoers.d/90-helios-ops` définit les commandes autorisées aux membres de `helios-ops` :

\- gestion du service `helios-collect.service` ;

\- démarrage et arrêt de `helios.target` ;

\- consultation des journaux des services Helios.



Des paramètres de délai d'authentification, de journalisation et d'enregistrement des entrées/sorties ont été configurés.



Les tests ont confirmé que Julien pouvait redémarrer `helios-collect.service`, mais pas `sshd.service`.



Les sessions sudo ont été consultées avec `sudoreplay -l`.



### Démonstration d'une mauvaise configuration



Une règle temporaire a autorisé Nadia à exécuter Vim en tant que root sans mot de passe.



La commande `:!/usr/bin/id` a démontré l'exécution avec l'identité root. L'ouverture d'un shell depuis Vim a également été testée.



La règle dangereuse a ensuite été supprimée.



### Alternative sécurisée



Une règle `sudoedit` a été configurée pour permettre à Nadia de modifier les fichiers du répertoire transport sans lui accorder un accès général à un éditeur exécuté en tant que root.



## Conclusion



Ce TP a permis de mettre en œuvre une gestion avancée des utilisateurs et groupes, une politique d'authentification renforcée, les permissions spéciales Unix, les ACL et une délégation contrôlée des privilèges sudo.



Les tests ont notamment démontré l'importance du bit setgid pour le partage de fichiers, du masque ACL dans le calcul des droits effectifs et du risque associé à l'autorisation d'éditeurs exécutés avec des privilèges root.



Les configurations et preuves sont regroupées dans les répertoires `configs/` et `captures/`.

