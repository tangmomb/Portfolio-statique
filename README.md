# Portfolio statique

Version autonome du portfolio de Tanguy M. Elle ne nécessite ni Node.js, ni Next.js, ni NestJS, ni base de données, ni backend en production.

## Mettre à jour le contenu

1. Modifier `update.xlsx` en conservant les quatre onglets et leurs en-têtes.
2. Fermer ou enregistrer le classeur.
3. Double-cliquer sur `mettre-a-jour.bat`.
4. Envoyer le dossier `data` sur l'hébergement.

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
4. Envoyer le nouveau fichier image et le dossier `data` sur l'hébergement.

## Tester localement

Les navigateurs empêchent généralement un fichier HTML ouvert par double-clic de lire du JSON local. Double-cliquer sur `apercu.bat`, puis laisser la fenêtre ouverte pendant le test. Cette commande sert seulement à la prévisualisation locale et n'est pas un backend de production.

## Déployer

Pour le premier déploiement, envoyer à la racine du domaine :

- `index.html` ;
- `styles.css` ;
- `app.js` ;
- `favicon.png` ;
- les dossiers `assets`, `data` et `images`.

Les fichiers `update.xlsx`, `mettre-a-jour.bat`, `apercu.bat`, `tools` et `README.md` restent sur l'ordinateur et ne sont pas nécessaires sur l'hébergement.

Après une simple modification du classeur, seul le dossier `data` doit être renvoyé.

## Structure du classeur

- `website` : `title`, `description`, `link`, `category`, `technologies`, `image`, `highlight`
- `design` : `image`, `category`, `description`
- `video` : `url`, `category`, `description`, `platform` (`nom` est facultatif)
- `photo` : `image`, `category`, `description`

