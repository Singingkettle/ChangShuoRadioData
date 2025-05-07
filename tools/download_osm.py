import requests
import os
import math
import time
import re

# --- Configuration ---
OVERPASS_URL = "https://overpass-api.de/api/interpreter"  # Use the .de mirror, often has lower load
OUTPUT_BASE_DIR = "appdata/map/osm"  # Base directory for storing datasets
BOX_SIZE_KM = 2.0  # Side length of each scene box (kilometers)
REQUEST_TIMEOUT = 1800  # HTTP request timeout (seconds)
API_DELAY = 15  # Pause time after each API call (seconds)

# --- Scene Definitions ---
# (Category Name: [(Latitude1, Longitude1, "Name1"), (Latitude2, Longitude2, "Name2"), ...])
# Note: Category name and Geographic Name will be sanitized for folder/file names
scenes = {
    "Dense_Urban_High_Rise": [
        (40.7580, -73.9855, "Times_Square_NYC"),
        (31.2397, 121.5050, "Lujiazui_Shanghai"),
        (35.6895, 139.6917, "Shinjuku_Tokyo"),
        (
            22.2818,
            114.1583,
            "Central_Hong_Kong",
        ),  # Slightly adjusted coord for better centering
        (51.5150, -0.0850, "Bank_Station_City_London"),
        (41.8789, -87.6280, "Willis_Tower_Vicinity_Chicago"),
        (43.6488, -79.3853, "Financial_District_Toronto"),
        (34.0522, -118.2437, "Civic_Center_Los_Angeles"),
        (25.1972, 55.2744, "Burj_Khalifa_Downtown_Dubai"),
        (-33.8650, 151.2094, "Circular_Quay_Sydney_CBD"),
    ],
    "Dense_Urban_Mid_Rise": [
        (48.8584, 2.2945, "Eiffel_Tower_Vicinity_Paris"),
        (41.9028, 12.4964, "Trevi_Fountain_Vicinity_Rome"),
        (
            39.9075,
            116.3972,
            "Forbidden_City_Vicinity_Beijing",
        ),  # Slightly adjusted coord
        (52.5170, 13.3889, "Brandenburg_Gate_Vicinity_Berlin"),
        (40.4168, -3.7038, "Puerta_del_Sol_Madrid"),
        (37.9838, 23.7275, "Plaka_District_Athens"),
        (-34.6037, -58.3816, "Plaza_de_Mayo_Buenos_Aires"),
        (45.4388, 12.3271, "Rialto_Bridge_Vicinity_Venice"),
        (59.9139, 10.7522, "Oslo_Central_Station_Vicinity"),
        (32.0853, 34.7818, "Sarona_Market_Tel_Aviv"),
    ],
    "Urban_Canyon": [
        (
            40.7568,
            -73.9752,
            "Park_Avenue_Midtown_NYC",
        ),  # Adjusted for better canyon feel
        (
            41.8818,
            -87.6327,
            "LaSalle_Street_Chicago_Loop",
        ),  # Adjusted for better canyon feel
        (
            34.0495,
            -118.2535,
            "Financial_District_LA_Canyon",
        ),  # Adjusted for better canyon feel
        (
            43.6500,
            -79.3820,
            "Bay_Street_Financial_District_Toronto",
        ),  # Adjusted for better canyon feel
        (
            35.6815,
            139.7660,
            "Marunouchi_District_Tokyo",
        ),  # Adjusted for better canyon feel
        (
            51.5120,
            -0.0930,
            "Queen_Victoria_Street_London",
        ),  # Adjusted for better canyon feel
        (48.8738, 2.2950, "Avenue_Kleber_Near_Arc_Triomphe_Paris"),  # Specific avenue
        (
            -33.8670,
            151.2070,
            "George_Street_Sydney_CBD",
        ),  # Adjusted for better canyon feel
        (
            31.2300,
            121.4750,
            "Nanjing_Road_Pedestrian_Street_Shanghai",
        ),  # Example canyon street
        (22.2805, 114.1580, "Queens_Road_Central_Hong_Kong"),  # Example canyon street
    ],
    "Mixed_Urban": [
        (47.6032, -122.3301, "Pioneer_Square_Seattle"),  # Adjusted coord slightly
        (37.7749, -122.4194, "Hayes_Valley_San_Francisco"),
        (51.5114, -0.1260, "Covent_Garden_London"),  # Adjusted coord slightly
        (40.7411, -73.9898, "Flatiron_District_NYC"),
        (38.9072, -77.0369, "Farragut_Square_Washington_DC"),
        (45.5017, -73.5673, "Downtown_Montreal_Near_McGill"),
        (52.3702, 4.8952, "Dam_Square_Vicinity_Amsterdam"),
        (-33.9249, 18.4241, "Cape_Town_City_Centre"),
        (19.4326, -99.1332, "Zocalo_Mexico_City"),
        (4.7110, -74.0721, "Teusaquillo_District_Bogota"),
    ],
    "Historical_City_Center": [
        (43.7714, 11.2542, "Florence_Duomo_Vicinity"),
        (50.0878, 14.4205, "Old_Town_Square_Prague"),
        (39.4702, -0.3768, "Valencia_Cathedral_Vicinity"),
        (37.9715, 23.7257, "Monastiraki_Square_Athens"),
        (55.7558, 37.6173, "Red_Square_Moscow"),
        (31.6295, -7.9811, "Jemaa_el_Fnaa_Marrakesh"),
        (30.0444, 31.2357, "Khan_el_Khalili_Cairo"),
        (13.7520, 100.4937, "Grand_Palace_Vicinity_Bangkok"),  # Adjusted coord slightly
        (-12.0464, -77.0428, "Plaza_Mayor_Lima"),
        (51.0504, 13.7373, "Frauenkirche_Dresden"),
    ],
    "Dense_Suburban": [
        # (Original 40.7128, -74.0060 was too central)
        (
            40.7558,
            -73.8855,
            "Jackson_Heights_Queens_NYC",
        ),  # REPLACEMENT: Dense Queens neighborhood
        (
            34.0050,
            -118.4450,
            "Westwood_Los_Angeles",
        ),  # Adjusted to a known dense suburban/urban mix area near UCLA
        (51.4500, -0.2000, "Richmond_London"),
        (48.8044, 2.1204, "Versailles_Town_Center_France"),  # Adjusted coord slightly
        (35.6467, 139.6500, "Setagaya_Ward_Tokyo"),  # Adjusted coord slightly
        (-33.8350, 151.1500, "Lane_Cove_Sydney"),  # Adjusted coord slightly
        (43.7500, -79.4500, "Yorkdale_Area_Toronto"),  # Near mall, dense suburban feel
        (
            29.9500,
            -95.5500,
            "Energy_Corridor_West_Houston",
        ),  # Adjusted to a dense suburban/commercial area
        (41.9000, -87.8500, "Elmwood_Park_Chicago_Suburbs"),  # Adjusted coord slightly
        (
            52.3000,
            4.8000,
            "Amstelveen_Stadshart_Netherlands",
        ),  # Centered on denser part
    ],
    "Sparse_Suburban": [
        (41.0339, -73.7629, "White_Plains_Suburbs_NY"),  # Adjusted coord slightly
        (34.1500, -118.7000, "Agoura_Hills_California"),
        (51.3760, -0.4000, "Weybridge_Surrey_UK"),  # More specific sparse suburb
        (
            47.6200,
            -122.1300,
            "Bellevue_Residential_Seattle_Eastside",
        ),  # More specific coord
        (
            33.6500,
            -117.8000,
            "Northwood_Irvine_California",
        ),  # Specific sparse neighborhood
        (42.3300, -71.2300, "Newton_Massachusetts_Suburbs"),  # Specific sparse suburb
        (-37.8500, 145.1000, "Glen_Waverley_Melbourne_Suburbs"),
        (
            49.2500,
            -122.9500,
            "Burnaby_Residential_Vancouver",
        ),  # Adjusted coord slightly
        (39.0840, -77.1528, "Potomac_Maryland_Suburbs"),  # Adjusted coord slightly
        (
            50.0500,
            8.3500,
            "Kelsterbach_Frankfurt_Suburbs",
        ),  # Specific sparse suburb near airport
    ],
    "University_Campus": [
        (42.3744, -71.1169, "Harvard_Yard_Cambridge_MA"),  # More specific
        (34.0689, -118.4452, "UCLA_Campus_Los_Angeles"),
        (51.7548, -1.2544, "Radcliffe_Camera_Oxford_UK"),  # Specific landmark
        (37.4275, -122.1697, "Stanford_University_Main_Quad"),  # Specific landmark
        (47.6553, -122.3035, "University_of_Washington_Seattle"),
        (35.7126, 139.7619, "University_of_Tokyo_Hongo_Campus"),
        (39.9997, 116.3086, "Peking_University_Campus_Beijing"),
        (-37.7963, 144.9614, "University_of_Melbourne_Parkville"),
        (43.6629, -79.3957, "University_of_Toronto_St_George"),
        (48.8469, 2.3446, "Sorbonne_University_Latin_Quarter_Paris"),
    ],
    "Industrial_Park": [
        (33.9740, -118.1700, "Commerce_Industrial_Area_LA"),  # Adjusted coord slightly
        (40.8100, -74.0750, "Secaucus_Industrial_NJ"),  # Adjusted coord slightly
        (51.4800, 0.1800, "Crossways_Business_Park_Dartford_UK"),  # Specific park
        (
            31.3500,
            121.2500,
            "Jiading_Industrial_Zone_Shanghai",
        ),  # Adjusted coord slightly
        (45.6000, -73.5000, "Anjou_Industrial_Park_Montreal"),  # Specific park
        (50.1150, 8.7450, "Frankfurt_Fechenheim_Industrial"),  # Specific area
        (24.9800, 55.1400, "Dubai_Industrial_City"),  # Adjusted coord slightly
        (34.6580, 135.4350, "Konohana_Ward_Industrial_Osaka"),  # Specific area
        (19.5400, -99.2100, "Tlalnepantla_Industrial_Mexico_City"),  # Specific area
        (-23.6500, -46.7500, "Santo_Amaro_Industrial_Sao_Paulo"),
    ],
    "Large_Urban_Park": [
        (40.7829, -73.9654, "Central_Park_NYC"),
        (51.5074, -0.1657, "Hyde_Park_London"),
        (48.8588, 2.2945, "Champ_de_Mars_Paris"),  # Re-centered on the park itself
        (
            37.8000,
            -122.4700,
            "Presidio_National_Park_San_Francisco",
        ),  # Adjusted coord slightly
        (-33.8680, 151.2180, "Royal_Botanic_Garden_Sydney"),  # More specific name/coord
        (52.5145, 13.3500, "Tiergarten_Berlin"),
        (
            34.1366,
            -118.2940,
            "Griffith_Park_Observatory_Vicinity_LA",
        ),  # More specific coord
        (43.6650, -79.3920, "Queens_Park_Toronto"),  # Re-centered on Queen's Park
        (35.6700, 139.7000, "Yoyogi_Park_Tokyo"),
        (40.4140, -3.6800, "El_Retiro_Park_Madrid"),
    ],
    "Airport_Vicinity": [
        (40.6413, -73.7781, "JFK_Airport_NYC"),
        (51.4700, -0.4543, "London_Heathrow_Airport_LHR"),
        (33.9416, -118.4085, "Los_Angeles_International_Airport_LAX"),
        (49.0097, 2.5479, "Charles_de_Gaulle_Airport_CDG_Paris"),
        (35.5494, 139.7798, "Tokyo_Haneda_Airport_HND"),
        (31.1444, 121.3403, "Shanghai_Hongqiao_Airport_SHA"),
        (50.0379, 8.5622, "Frankfurt_Airport_FRA"),
        (33.6407, -84.4277, "Hartsfield_Jackson_Atlanta_Airport_ATL"),
        (25.2532, 55.3657, "Dubai_International_Airport_DXB"),
        (52.3105, 4.7683, "Amsterdam_Schiphol_Airport_AMS"),
    ],
    "Stadium_Arena_Complex": [
        (51.5560, -0.2795, "Wembley_Stadium_London"),
        (40.8296, -73.9262, "Yankee_Stadium_Bronx_NYC"),
        (41.9340, 12.4545, "Stadio_Olimpico_Rome"),  # Adjusted coord slightly
        (
            -33.8900,
            151.2250,
            "Sydney_Cricket_Ground_Moore_Park",
        ),  # Adjusted coord slightly
        (48.2188, 11.6245, "Allianz_Arena_Munich"),
        (
            39.9060,
            -75.1670,
            "South_Philadelphia_Sports_Complex",
        ),  # Adjusted coord slightly
        (34.1614, -118.1874, "Rose_Bowl_Stadium_Pasadena"),
        (43.6414, -79.3894, "Scotiabank_Arena_Rogers_Centre_Toronto"),
        # (Original 39.9035, 116.4140 was Beijing Railway Station)
        (
            39.9915,
            116.3917,
            "Beijing_National_Stadium_Birds_Nest",
        ),  # REPLACEMENT: Olympic Park stadium
        (
            -22.9121,
            -43.2301,
            "Maracana_Stadium_Rio_de_Janeiro",
        ),  # Adjusted coord slightly
    ],
    "Shopping_Mall_Retail_Park": [
        (44.8548, -93.3771, "Mall_of_America_Bloomington_MN"),
        (25.1181, 55.1800, "Mall_of_the_Emirates_Dubai"),
        (51.4570, -0.9720, "The_Oracle_Reading_UK"),  # Adjusted coord slightly
        (33.6900, -117.8800, "South_Coast_Plaza_Costa_Mesa_CA"),
        (43.7770, -79.3430, "CF_Fairview_Mall_Toronto"),  # Adjusted coord slightly
        (
            34.1430,
            -118.2580,
            "Glendale_Galleria_Americana_CA",
        ),  # Adjusted coord slightly
        (53.4140, -2.2920, "Trafford_Centre_Manchester_UK"),
        (30.4432, -91.1298, "Mall_of_Louisiana_Baton_Rouge"),
        (-33.7850, 151.1820, "Macquarie_Centre_Sydney"),
        (
            35.1700,
            136.9060,
            "Sakae_Shopping_District_Nagoya",
        ),  # Adjusted coord slightly
    ],
    "Major_Train_Station_Area": [
        (40.7505, -73.9934, "Penn_Station_NYC"),
        (35.6812, 139.7671, "Tokyo_Station_Marunouchi_Exit"),
        (48.8762, 2.3581, "Gare_du_Nord_Paris"),
        # (Original 51.5171, -0.1171 was Holborn)
        (
            51.5310,
            -0.1230,
            "Kings_Cross_St_Pancras_London",
        ),  # REPLACEMENT: Major rail hub
        (52.5251, 13.3694, "Berlin_Hauptbahnhof"),
        (31.2460, 121.4580, "Shanghai_Railway_Station"),
        # (Original 41.4036, 2.1744 was Sagrada Familia area)
        (41.3790, 2.1400, "Barcelona_Sants_Station"),  # REPLACEMENT: Main station
        (45.4669, 9.1900, "Milano_Centrale_Station"),
        (28.6426, 77.2220, "New_Delhi_Railway_Station"),
        (-33.8820, 151.2060, "Central_Station_Sydney"),
    ],
    "Waterfront_Harbor_Area": [
        (-33.8591, 151.2131, "Sydney_Opera_House_Circular_Quay"),
        (47.6050, -122.3400, "Seattle_Waterfront_Piers"),
        (37.8080, -122.4100, "Fishermans_Wharf_San_Francisco"),
        (43.6400, -79.3750, "Toronto_Harbourfront_Centre"),
        (53.5450, 9.9850, "HafenCity_Hamburg"),
        (41.3750, 2.1800, "Port_Vell_Barcelona"),
        (-33.9180, 18.4210, "V_and_A_Waterfront_Cape_Town"),
        (51.9180, 4.4880, "Kop_van_Zuid_Rotterdam"),
        (22.2855, 114.1580, "Victoria_Harbour_Central_Waterfront_HK"),
        (32.7157, -117.1611, "Embarcadero_San_Diego"),
    ],
    "Bridge_Crossing_Area": [
        (37.8199, -122.4783, "Golden_Gate_Bridge_South_End_SF"),
        (40.7061, -73.9969, "Brooklyn_Bridge_Manhattan_Side_NYC"),
        (51.5055, -0.0754, "Tower_Bridge_London"),  # Centered on bridge
        (-33.8523, 151.2108, "Sydney_Harbour_Bridge_South_Pylon"),
        (
            41.3980,
            2.1990,
            "Pont_del_Treball_Digne_Barcelona",
        ),  # Adjusted coord slightly
        (
            34.6180,
            135.0220,
            "Akashi_Kaikyo_Bridge_Kobe_Side",
        ),  # Adjusted coord slightly
        (
            47.6000,
            -122.2800,
            "I90_Floating_Bridge_Mercer_Island_Seattle",
        ),  # Adjusted coord slightly
        (38.8893, -77.0500, "Arlington_Memorial_Bridge_DC"),
        (48.8415, 2.3660, "Pont_dAusterlitz_Paris"),  # Adjusted coord slightly
        (38.3000, 21.7750, "Rio_Antirrio_Bridge_Greece"),  # Adjusted coord slightly
    ],
    "Rural_Village_Center": [
        (51.7500, -1.6000, "Burford_Village_Cotswolds_UK"),
        (
            44.3450,
            10.6450,
            "Castelnovo_ne_Monti_Vicinity_Italy",
        ),  # Specific town nearby
        (
            47.3300,
            1.8300,
            "Neuvy-sur-Barangeon_Village_France",
        ),  # Specific village nearby
        (38.2800, -1.1300, "Fortuna_Town_Murcia_Spain"),  # Specific town nearby
        (40.6500, -76.3800, "Pine_Grove_Pennsylvania_USA"),  # Specific town nearby
        (
            35.1100,
            135.8200,
            "Ohara_Village_Kyoto_Prefecture_Japan",
        ),  # Specific village nearby
        (50.8000, 6.8000, "Erftstadt_Lechenich_Germany"),  # Specific town nearby
        (46.8000, 8.3000, "Sachseln_Village_Switzerland"),  # Specific village nearby
        (
            -33.9580,
            18.8600,
            "Stellenbosch_Town_Center_South_Africa",
        ),  # Adjusted coord slightly
        (43.1000, -71.7500, "Weare_New_Hampshire_USA"),  # Specific town nearby
    ],
    "Open_Farmland_Flat": [
        (41.5000, -93.0000, "Jasper_County_Iowa_USA"),
        (49.5000, 2.5000, "Santerre_Plateau_Picardy_France"),
        (52.6000, 0.3000, "The_Fens_Cambridgeshire_UK"),  # Adjusted coord slightly
        (35.5000, -101.5000, "Texas_Panhandle_Farmland_USA"),  # Adjusted coord slightly
        (
            -34.5000,
            146.5000,
            "Riverina_Farmland_NSW_Australia",
        ),  # Adjusted coord slightly
        (
            45.2000,
            8.5000,
            "Po_Valley_Farmland_Piedmont_Italy",
        ),  # Adjusted coord slightly
        (52.0000, 19.0000, "Central_Poland_Farmland_Lodz_Voivodeship"),
        (-33.0000, -60.0000, "The_Pampas_Santa_Fe_Province_Argentina"),
        (48.0000, 33.0000, "Kirovohrad_Oblast_Farmland_Ukraine"),
        (47.0000, -100.0000, "Central_North_Dakota_Farmland_USA"),
    ],
    "Hilly_Farmland_Rural_Area": [
        (44.5000, 10.8000, "Emilian_Apennines_Foothills_Italy"),
        (51.0000, -2.5000, "Blackmore_Vale_Dorset_UK"),
        (46.5000, 6.5000, "Lavaux_Vineyards_Vaud_Switzerland"),  # Specific hilly area
        (39.5000, -78.0000, "Appalachian_Foothills_WV_MD_USA"),
        (43.0000, -1.5000, "Baztan_Valley_Navarre_Spain"),  # Specific hilly area
        (
            -41.2000,
            173.2000,
            "Tasman_District_Hills_New_Zealand",
        ),  # Adjusted coord slightly
        (
            36.3000,
            140.2000,
            "Mount_Tsukuba_Foothills_Ibaraki_Japan",
        ),  # Adjusted coord slightly
        (
            50.0000,
            10.5000,
            "Steigerwald_Nature_Park_Bavaria_Germany",
        ),  # Specific hilly park area
        (
            45.4000,
            -122.8000,
            "Tualatin_Valley_Hills_Oregon_USA",
        ),  # Adjusted coord slightly
        (38.5000, 22.5000, "Mount_Parnassus_Foothills_Greece"),  # Near Delphi
    ],
    "Coastal_Town": [
        # (Original 43.6590, 1.4442 was Toulouse - inland)
        (43.4810, -1.5560, "Biarritz_France"),  # REPLACEMENT: French coastal town
        (36.5700, -4.9000, "Marbella_Old_Town_Spain"),
        (34.4208, -119.6982, "Santa_Barbara_Stearns_Wharf_CA"),
        (50.7200, -1.8800, "Bournemouth_Pier_UK"),
        (
            -34.0540,
            23.3700,
            "Plettenberg_Bay_Central_Beach_SA",
        ),  # Adjusted coord slightly
        (
            44.1419,
            9.6968,
            "Vernazza_Cinque_Terre_Italy",
        ),  # Specific Cinque Terre village
        # (Original 38.7223, -9.1393 was Lisbon center - large city)
        (
            38.7115,
            -9.4210,
            "Cascais_Portugal",
        ),  # REPLACEMENT: Famous coastal town near Lisbon
        (-28.1600, 153.5400, "Surfers_Paradise_Gold_Coast_Australia"),
        (32.6500, -16.9000, "Funchal_Marina_Madeira"),
        (52.1400, -10.2700, "Dingle_Town_Ireland"),  # More specific
    ],
    "Hilly_Urban_Area": [
        (
            37.7749,
            -122.4194,
            "Civic_Center_Hills_San_Francisco",
        ),  # Name emphasizes hills
        (
            -22.9068,
            -43.1729,
            "Lapa_Santa_Teresa_Hills_Rio_de_Janeiro",
        ),  # Name emphasizes hills
        (38.7100, -9.1400, "Alfama_District_Hills_Lisbon"),  # Specific hilly district
        (41.3950, 2.1530, "Gracia_District_Hills_Barcelona"),  # Specific hilly district
        (47.4925, 19.0400, "Gellert_Hill_Buda_Budapest"),  # Specific hill
        (40.8450, 14.2450, "Vomero_Hill_Naples"),  # Specific hill
        (37.9750, 23.7280, "Acropolis_Slopes_Athens"),  # Specific hill
        (36.8485, 174.7633, "Auckland_CBD_Hills"),
        (47.6100, -122.3320, "Downtown_Seattle_Hills"),  # Name emphasizes hills
        (
            39.9526,
            -75.1652,
            "Center_City_Philadelphia",
        ),  # Kept original, less hilly but still urban context requested
    ],
    "Dense_Forest_Edge_Woodland": [
        (
            48.9500,
            8.4000,
            "Black_Forest_Edge_Karlsruhe_Germany",
        ),  # Adjusted coord slightly
        (
            45.4500,
            -73.9500,
            "Morgan_Arboretum_Vicinity_Montreal_QC",
        ),  # Specific wooded area
        (35.8000, -78.8000, "Umstead_State_Park_Edge_Raleigh_NC"),  # Specific park edge
        (51.3000, 0.5000, "Kent_Downs_Woodland_UK"),
        (
            47.5500,
            -122.0500,
            "Cougar_Mountain_Park_Edge_Issaquah_WA",
        ),  # Adjusted coord slightly
        (48.8000, 2.5000, "Foret_de_Bondy_Edge_Paris_Suburbs"),
        (35.6500, 139.4000, "Tama_Hills_Forest_Edge_Tokyo"),  # Adjusted coord slightly
        (59.3000, 18.2000, "Nacka_Nature_Reserve_Edge_Stockholm"),  # Specific reserve
        (
            43.1500,
            -79.1500,
            "Niagara_Glen_Nature_Reserve_ON_Canada",
        ),  # Specific reserve
        (
            -34.1000,
            151.0500,
            "Royal_National_Park_Edge_Sydney",
        ),  # Adjusted coord slightly
    ],
    "Orchard_Vineyard_Area": [
        (38.5000, -122.5000, "Napa_Valley_Vineyards_CA_USA"),
        (44.8000, -0.6000, "Medoc_Vineyards_Bordeaux_France"),
        (
            43.5000,
            11.3000,
            "Chianti_Classico_Vineyards_Tuscany_Italy",
        ),  # Adjusted coord slightly
        (
            -33.8000,
            18.8000,
            "Stellenbosch_Winelands_South_Africa",
        ),  # Adjusted coord slightly
        (49.8000, 8.0000, "Rheinhessen_Vineyards_Germany"),
        (
            -33.3000,
            -71.0000,
            "Casablanca_Valley_Vineyards_Chile",
        ),  # Adjusted coord slightly
        (-41.5000, 173.8000, "Marlborough_Vineyards_New_Zealand"),
        (46.1000, 4.7000, "Beaujolais_Vineyards_France"),  # Adjusted coord slightly
        (
            45.3000,
            -123.0000,
            "Willamette_Valley_Vineyards_Oregon_USA",
        ),  # Adjusted coord slightly
        (
            41.6500,
            -4.0000,
            "Ribera_del_Duero_Vineyards_Spain",
        ),  # Adjusted coord slightly
    ],
    "Open_Ocean_Area": [
        (35.0000, -45.0000, "North_Atlantic_Ocean_Mid_Atlantic_Ridge_Vicinity"),
        (0.0000, -160.0000, "Central_Pacific_Ocean_Near_Line_Islands"),
        (-20.0000, 80.0000, "Central_Indian_Ocean"),
        (-50.0000, 160.0000, "South_Pacific_Ocean_Near_Antarctic_Convergence"),
        (40.0000, 170.0000, "North_Pacific_Ocean_East_of_Japan_Trench"),
        (35.0000, 25.0000, "Mediterranean_Sea_South_of_Crete"),
        (-10.0000, -30.0000, "South_Atlantic_Ocean_Near_Mid_Atlantic_Ridge"),
        (15.0000, -75.0000, "Caribbean_Sea_Central"),
        (60.0000, 5.0000, "North_Sea_Off_Norway_Coast"),
        (10.0000, 115.0000, "South_China_Sea_Spratly_Islands_Area"),
    ],
    "Desert_Area": [
        (24.0000, 12.0000, "Sahara_Desert_Tassili_nAjjer_Vicinity_Algeria_Libya"),
        (21.0000, 52.0000, "Rub_al_Khali_Empty_Quarter_Saudi_Arabia"),
        (44.0000, 108.0000, "Gobi_Desert_Mongolia"),
        (-25.0000, 22.0000, "Kalahari_Desert_Botswana"),
        (-28.0000, 125.0000, "Great_Victoria_Desert_Australia"),
        (35.0000, -116.0000, "Mojave_Desert_California_USA"),
        (-24.0000, -69.0000, "Atacama_Desert_Chile"),
        (27.0000, 71.0000, "Thar_Desert_Rajasthan_India"),
        (30.5000, 34.5000, "Negev_Desert_Israel"),  # Adjusted coord slightly
        (40.7800, -113.8600, "Great_Salt_Lake_Desert_Bonneville_Salt_Flats_Utah_USA"),
    ],
}
# --- Helper Functions ---


def sanitize_filename(name):
    """Removes or replaces characters problematic for filenames/folders."""
    # Remove leading/trailing whitespace
    name = name.strip()
    # Replace spaces and common separators with underscores
    name = re.sub(r"[\s/\\:]+", "_", name)
    # Remove other potentially problematic characters (adjust as needed)
    # Allows alphanumeric, underscore, hyphen, period
    name = re.sub(r"[^\w\-\.]", "", name)
    # Replace multiple consecutive underscores/hyphens with a single one
    name = re.sub(r"[_]{2,}", "_", name)
    name = re.sub(r"[-]{2,}", "-", name)
    # Avoid starting or ending with underscore/hyphen
    name = name.strip("_-")
    # Handle potential empty name after sanitization
    if not name:
        name = "unnamed"
    return name


def calculate_bounding_box(lat_deg, lon_deg, size_km):
    """
    Calculates an approximate bounding box centered at lat/lon.
    Returns (min_lat, min_lon, max_lat, max_lon)
    Note: This approximation works reasonably well for small distances like 3km,
          but longitude conversion accuracy decreases at higher latitudes.
    """
    lat_rad = math.radians(lat_deg)
    # Earth radius in km (approximation)
    earth_radius_km = 6371.0

    # Calculate latitude delta (relatively constant)
    delta_lat_rad = (size_km / 2.0) / earth_radius_km
    delta_lat_deg = math.degrees(delta_lat_rad)

    # Calculate longitude delta (depends on latitude)
    # Radius of the parallel circle at the given latitude
    parallel_radius_km = earth_radius_km * math.cos(lat_rad)
    # Avoid division by zero near poles, although unlikely for typical scene locations
    if parallel_radius_km < 0.1:
        # Fallback for poles: use a simpler approximation or handle differently.
        # For a 3km box, this edge case is less critical.
        # Using global average degree size could be one way, but let's use a small latitude.
        print(
            f"  Warning: Calculating longitude delta near pole for {lat_deg}, {lon_deg}. Using approximation."
        )
        delta_lon_deg = math.degrees(
            (size_km / 2.0) / (earth_radius_km * math.cos(math.radians(1)))
        )
    else:
        delta_lon_rad = (size_km / 2.0) / parallel_radius_km
        delta_lon_deg = math.degrees(delta_lon_rad)

    min_lat = lat_deg - delta_lat_deg
    max_lat = lat_deg + delta_lat_deg
    min_lon = lon_deg - delta_lon_deg
    max_lon = lon_deg + delta_lon_deg

    # Optional: Ensure longitude stays within -180 to 180 range if needed
    # This is unlikely to be necessary for a small 3km box unless crossing the dateline.
    # min_lon = (min_lon + 180) % 360 - 180
    # max_lon = (max_lon + 180) % 360 - 180

    return (min_lat, min_lon, max_lat, max_lon)


def download_osm_data(bbox, output_filepath):
    """Downloads OSM data for the given bounding box using Overpass API."""
    min_lat, min_lon, max_lat, max_lon = bbox
    # Construct the Overpass QL query
    # Fetches all nodes, ways, and relations within the bbox, including their members/nodes
    # [out:xml] specifies XML output format
    # [timeout:...] sets server-side timeout
    # out body; gets elements with tags
    # >; recurses down (ways -> nodes)
    # out skel qt; gets remaining geometry efficiently, sorted by quadtree index (often faster)
    overpass_query = f"""
    [out:xml][timeout:{REQUEST_TIMEOUT}];
    (
      node({min_lat},{min_lon},{max_lat},{max_lon});
      way({min_lat},{min_lon},{max_lat},{max_lon});
      relation({min_lat},{min_lon},{max_lat},{max_lon});
    );
    out body;
    >;
    out skel qt;
    """

    print(
        f"  Querying Overpass API for bbox: ({min_lat:.4f}, {min_lon:.4f}, {max_lat:.4f}, {max_lon:.4f})..."
    )
    # Be polite: identify your script. Replace with your actual contact info if needed.
    headers = {
        "User-Agent": "PythonOSMDownloader/1.1 (for academic research; contact@example.com)"
    }
    try:
        response = requests.post(
            OVERPASS_URL,
            data=overpass_query,
            timeout=REQUEST_TIMEOUT + 10,  # Add buffer to client timeout
            headers=headers,
        )
        response.raise_for_status()  # Raise an exception for bad status codes (4xx or 5xx)

        print(f"  Saving data to {output_filepath}...")
        with open(
            output_filepath, "wb"
        ) as f:  # Write in binary mode to preserve encoding from server
            f.write(response.content)
        print("  Success.")
        return True

    except requests.exceptions.Timeout:
        print(f"  Error: Request timed out after {REQUEST_TIMEOUT + 10} seconds.")
        return False
    except requests.exceptions.HTTPError as e:
        print(f"  Error: HTTP Error: {e.response.status_code} {e.response.reason}")
        print(f"  Response body (first 500 chars): {e.response.text[:500]}...")
        if e.response.status_code == 429:
            print("  Hint: Received 'Too Many Requests'. Try increasing API_DELAY.")
        elif e.response.status_code >= 500:
            print(
                "  Hint: Server error. Overpass API might be overloaded or down. Try again later."
            )
        return False
    except requests.exceptions.RequestException as e:
        print(f"  Error: General request error: {e}")
        return False
    except Exception as e:
        print(f"  An unexpected error occurred during download: {e}")
        return False


# --- Main Execution ---

if __name__ == "__main__":
    print("Starting OSM data download process...")
    # Create base directory if it doesn't exist
    os.makedirs(OUTPUT_BASE_DIR, exist_ok=True)

    total_locations = sum(len(coords) for coords in scenes.values())
    processed_count = 0
    success_count = 0
    failed_count = 0

    for category, locations in scenes.items():
        sanitized_category = sanitize_filename(category)
        category_dir = os.path.join(OUTPUT_BASE_DIR, sanitized_category)
        os.makedirs(category_dir, exist_ok=True)
        print(f"\nProcessing Category: {category} (saving to '{category_dir}')")

        for i, (lat, lon, name) in enumerate(locations):
            processed_count += 1
            print(
                f" Processing location {i+1}/{len(locations)} ({processed_count}/{total_locations}): '{name}' (Lat={lat:.4f}, Lon={lon:.4f})"
            )

            # Sanitize the geographic name for the filename
            sanitized_name = sanitize_filename(name)

            # Define output filename including the sanitized name
            # Using limited precision for coordinates in filename for brevity
            filename = f"{sanitized_category}_{sanitized_name}_{lat:.4f}_{lon:.4f}.osm"
            output_path = os.path.join(category_dir, filename)

            # Skip if file already exists
            if os.path.exists(output_path):
                print(f"  File '{filename}' already exists. Skipping download.")
                success_count += 1  # Count skipped as success for summary consistency
                continue  # Move to the next location in the list

            # Calculate bounding box
            bbox = calculate_bounding_box(lat, lon, BOX_SIZE_KM)

            # Download data
            success = download_osm_data(bbox, output_path)

            if success:
                success_count += 1
            else:
                failed_count += 1
                # Optional: Add more robust error handling here, e.g., retry mechanism

            # Polite delay between API requests to avoid being blocked (429 error)
            if (
                processed_count < total_locations
            ):  # No need to wait after the last request
                print(f"  Waiting for {API_DELAY} seconds before next request...")
                time.sleep(API_DELAY)

    print("\n--- Download Summary ---")
    print(f"Total locations attempted: {processed_count}")
    print(f"Successfully downloaded (or skipped existing): {success_count}")
    print(f"Failed downloads: {failed_count}")
    print(f"Data saved in subfolders under: {os.path.abspath(OUTPUT_BASE_DIR)}")
    print("Download process finished.")
