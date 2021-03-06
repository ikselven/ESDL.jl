const known_vargroups = Dict(
"Atmosphere"=>[
            "aerosol_optical_thickness_1610",
            "aerosol_optical_thickness_550",
            "aerosol_optical_thickness_555",
            "aerosol_optical_thickness_659",
            "aerosol_optical_thickness_865",
            "air_temperature_2m",
            "ozone",
            "potential_evaporation",
            "precipitation",
            "water_vapour"],
"_Atmosphere"=>["Rg",
            "air_temperature_2m",
            "air_temperature_max",
            "air_temperature_min",
            "cloud_cover",
            "relative_humidity",
            "potential_evaporation",
            "precipitation",
            "vapour_pressure_deficit",
            "wind"],
"Biosphere"=>["bare_soil_evaporation",
            "black_sky_albedo",
            "burnt_area",
            "c_emissions",
            "evaporation",
            "evaporative_stress",
            "gross_primary_productivity",
            "interception_loss",
            "land_surface_temperature",
            "latent_energy",
            "net_ecosystem_exchange",
            "open_water_evaporation",
            "root_moisture",
            "sensible_heat",
            "soil_moisture",
            "surface_moisture",
            "terrestrial_ecosystem_respiration",
            "transpiration",
            "white_sky_albedo"],
"_Biosphere"=>["bare_soil_evaporation",
            "black_sky_albedo",
            "burnt_area",
            "c_emissions",
            "evaporation",
            "evaporative_stress",
            "fpar_fluxcom",
            "gross_primary_productivity",
            "interception_loss",
            "latent_energy",
            "net_ecosystem_exchange",
            "open_water_evaporation",
            "root_moisture",
            "sensible_heat",
            "snow_sublimation",
            "surface_moisture",
            "terrestrial_ecosystem_respiration",
            "transpiration",
            "white_sky_albedo"],
"Fluxcom"=>["gross_primary_productivity",
            "net_ecosystem_exchange",
            "terrestrial_ecosystem_respiration"],
"GLEAM"=>  ["evaporation",
            "evaporative_stress",
            "potential_evaporation",
            "interception_loss",
            "root_moisture",
            "surface_moisture",
            "bare_soil_evaporation",
            "snow_sublimation",
            "transpiration",
            "open_water_evaporation"]
)
