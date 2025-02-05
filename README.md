# PassTester_Elymaro
Identifiez les comptes les plus vulnérables aux attaques par dictionnaire

Objectif

PassTester est conçu pour identifier les mots de passe des utilisateurs les plus exposés aux attaques par dictionnaire, afin de les encourager à adopter des mots de passe plus sécurisés.

Fonctionnement

Extraction des données : 

L’outil extrait la base NTDS de l’Active Directory (nécessite des privilèges administrateur de domaine). Cette opération peut être réalisée depuis n'importe quelle machine du domaine.
Analyse des hachages :

- Le script récupère les hachages NTLM des utilisateurs et les compare à une base contenant près d'un milliard de mots de passe divulgués.
- Seuls les 5 premiers caractères hexadécimaux du hachage NTLM sont transmis, garantissant ainsi une confidentialité partielle.
- Environ 800 correspondances possibles sont renvoyées par requête, puis l’analyse finale est effectuée localement pour confirmer les vulnérabilités.

Bonnes pratiques :

- Lors d’un audit, il est recommandé d’éviter d’effectuer cette analyse depuis l’adresse IP publique de l’entreprise afin de limiter les risques de traçabilité inversée.
- Une fois l’audit terminé, les fichiers d’extraction NTDS doivent être supprimés pour éviter toute compromission des données.

Clause de responsabilité

PassTester est exclusivement destiné à la recherche, à l’éducation et aux audits de sécurité autorisés. Il vise à aider les professionnels et les chercheurs à identifier les vulnérabilités et à renforcer la sécurité des systèmes.

Toute utilisation de cet outil doit être précédée d’un consentement explicite de toutes les parties concernées. L’usage non autorisé peut entraîner de lourdes conséquences juridiques. Les utilisateurs sont entièrement responsables du respect des lois et réglementations en vigueur en matière de cybersécurité et d’accès aux systèmes numériques.

Le créateur de PassTester décline toute responsabilité en cas d'utilisation abusive ou illicite et ne pourra être tenu responsable des dommages résultant d'un usage inapproprié de l’outil.
