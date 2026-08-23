# Portfolio statique

Version autonome du portfolio de Tanguy M. Elle ne nécessite ni Node.js, ni Next.js, ni NestJS, ni base de données, ni backend en production.

## Mettre à jour le contenu

1. Modifier `update.xlsx` en conservant les quatre onglets et leurs en-têtes.
2. Fermer ou enregistrer le classeur.
3. Double-cliquer sur `mettre-a-jour.bat`.
4. Enregistrer puis envoyer les changements sur GitHub :

   ```powershell
   git add update.xlsx data
   git commit -m "Met à jour le contenu du portfolio"
   git push origin main
   ```

GitHub Actions publie alors automatiquement le site sur l'hébergement IONOS.

Le générateur repose uniquement sur PowerShell, déjà fourni avec Windows. Il ignore les lignes vides formatées par Excel et produit :

- `data/all.json`, utilisé par le site ;
- `data/websites.json` ;
- `data/designs.json` ;
- `data/videos.json` ;
- `data/photos.json`.

Les URL Google Storage dont le fichier existe dans `images` sont automatiquement remplacées par une adresse locale. Si un média manque, l'URL distante est conservée et un avertissement est affiché.

## Ajouter une image

1. Copier l'image dans `images`.
2. Dans la colonne `image` du classeur, utiliser soit son nom (`mon-image.jpg`), soit son ancienne URL Google Storage.
3. Relancer `mettre-a-jour.bat`.
4. Envoyer les changements sur GitHub :

   ```powershell
   git add update.xlsx images data
   git commit -m "Ajoute une image au portfolio"
   git push origin main
   ```

## Tester localement

Les navigateurs empêchent généralement un fichier HTML ouvert par double-clic de lire du JSON local. Double-cliquer sur `apercu.bat`, puis laisser la fenêtre ouverte pendant le test. Cette commande sert seulement à la prévisualisation locale et n'est pas un backend de production.

## Déploiement automatique sur IONOS

Le workflow [`.github/workflows/deploy-ionos.yml`](.github/workflows/deploy-ionos.yml) s'exécute après chaque `git push` sur la branche `main`. Il envoie par SFTP les fichiers publiés dans le dossier auquel le compte IONOS est limité (`/tanguymfr/`).

Les fichiers de travail ne sont pas envoyés : `update.xlsx`, les fichiers `.bat`, le dossier `tools`, le README et la configuration GitHub restent dans le dépôt.

### Configuration initiale

Dans GitHub, ouvrir **Settings → Secrets and variables → Actions** puis créer les secrets de dépôt suivants :

- `FTP_SERVER` : le nom du serveur SFTP fourni par IONOS, sans `sftp://` ;
- `FTP_USERNAME` : le nom d'utilisateur SFTP ;
- `FTP_PASSWORD` : le mot de passe SFTP.

Le workflow utilise le protocole SFTP sur le port 22. Ne jamais enregistrer ces valeurs dans le dépôt ou dans ce fichier.

Une fois ces secrets créés, chaque push sur `main` déclenche le déploiement. Son état est visible dans l'onglet **Actions** du dépôt GitHub.

## Structure du classeur

- `website` : `title`, `description`, `link`, `category`, `technologies`, `image`, `highlight`
- `design` : `image`, `category`, `description`
- `video` : `url`, `category`, `description`, `platform` (`nom` est facultatif)
- `photo` : `image`, `category`, `description`
