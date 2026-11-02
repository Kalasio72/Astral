-- Astral BaseWars — configuration.
-- Fichier modifiable par les administrateurs. Chaque valeur est vérifiée au démarrage (astral/core/sv_config.lua) :
-- une valeur invalide est remplacée par sa valeur par défaut et signalée dans la console et dans astral_diag.
-- Ne rien mettre de secret ici : ce fichier est aussi envoyé aux joueurs.

Astral.Config = {
	Logs = {
		-- Intervalle (secondes) entre deux écritures groupées des journaux en base
		FlushInterval = 10,
		-- Nombre maximal de lignes en attente ; au-delà, les plus anciennes sont abandonnées (et comptées)
		MaxQueue = 2000,
		-- Nombre maximal de lignes écrites par requête
		BatchSize = 200,
		-- Les journaux plus vieux que ce nombre de jours sont supprimés au démarrage (0 = jamais)
		RetentionDays = 30,
	},
	Net = {
		-- Rejets réseau : un même joueur n'est journalisé qu'une fois par période (secondes)
		RejectLogInterval = 10,
	},
	Diagnostics = {
		-- Nombre de classes d'entités affichées par astral_diag
		TopEntityClasses = 10,
	},
	-- Règles affichées dans le menu F3 (onglet Règles). À adapter par l'administration du serveur.
	Rules = {
		"Pas de triche, de script externe ni d'exploitation de bug : signalez-les aux administrateurs.",
		"Les raids se lancent uniquement depuis le menu F3 (onglet Raids) ; détruire une base hors raid est interdit.",
		"Une base doit avoir une entrée accessible (fading door autorisée) : pas de base totalement fermée.",
		"Pas de construction autour du point d'apparition.",
		"Respect dans le chat : pas d'insultes, de harcèlement ni de spam.",
		"Une seule base par joueur ou par faction.",
		"Les décisions des administrateurs s'appliquent ; contestez-les calmement sur le Discord.",
	},
	Economy = {
		-- Fenêtre (secondes) sur laquelle on additionne les gains d'un joueur pour détecter une anomalie
		AlertWindow = 300,
		-- Gain sur la fenêtre au-delà duquel une alerte est journalisée et envoyée aux admins
		AlertGain = 5000000,
	},
	Events = {
		-- Délai minimal (secondes) entre la fin d'un événement automatique et le suivant
		AutoInterval = 2700,
		-- Durée d'un événement (secondes)
		Duration = 600,
		-- Nombre minimal de joueurs connectés pour un événement automatique
		MinPlayers = 2,
	},
	Industry = {
		-- Rayon (unités) dans lequel les machines d'un même propriétaire échangent des ressources
		TransferRadius = 400,
		-- Intervalle (secondes) entre deux échanges automatiques
		TransferInterval = 5,
		-- Foreuse : secondes par minerai extrait, stock interne maximal
		DrillSecondsPerOre = 6,
		DrillBuffer = 40,
		-- Raffinerie : secondes par lingot, minerais consommés par lingot, stocks internes
		RefinerySecondsPerIngot = 8,
		RefineryOrePerIngot = 2,
		RefineryBuffer = 40,
		-- Conteneur : capacité totale (toutes ressources confondues)
		ContainerCapacity = 500,
	},
	-- Marché entre joueurs (valeurs de départ : à valider par le propriétaire, voir NEXT_STEPS.md)
	Market = {
		-- Taxe prélevée sur le produit de chaque vente (pourcentage, argent détruit)
		TaxPercent = 5,
		-- Offres ouvertes au maximum par joueur
		MaxOrders = 5,
		-- Prix unitaire autorisé, en multiple de la valeur de référence de la ressource (limite le blanchiment entre comptes)
		MinPriceFactor = 0.25,
		MaxPriceFactor = 10,
		-- Quantité maximale par offre
		MaxQty = 500,
	},
}
