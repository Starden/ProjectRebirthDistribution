-- Generated client presentation data for the server-authoritative DK numeric package.
-- Keep this file synchronized with 2026_08_22_05_rebirth_dk_complete_numeric_v2.sql.

local data = {
    addonVersion = "1.1.1",
    schemaVersion = 1,
    dataVersion = 3,
    expectedRowCount = 52,
    realm = "Rebirth",
    packageSha256 = "234D898B1E9C41DBD35EE46A7D179853810E775604A1C2AF5E222528110ADBF1",
    abilities = {},
    spellIds = {},
}

local function Ability(code, title, targetSpellId, maxCustomLevel)
    local ability = {
        code = code,
        title = title,
        targetSpellId = targetSpellId,
        maxCustomLevel = maxCustomLevel,
        rows = {},
    }
    data.abilities[code] = ability
    data.spellIds[targetSpellId] = ability
end

local function Row(code, rank, level, valueMin, valueMax, weaponDamagePct, numericType)
    local ability = data.abilities[code]
    table.insert(ability.rows, {
        rank = rank,
        level = level,
        valueMin = valueMin,
        valueMax = valueMax,
        weaponDamagePct = weaponDamagePct,
        numericType = numericType,
    })
end

Ability("blood_strike", "Blood Strike", 45902, 54)
Ability("death_coil", "Death Coil", 47541, 54)
Ability("icy_touch", "Icy Touch", 45477, 54)
Ability("plague_strike", "Plague Strike", 45462, 54)
Ability("death_strike", "Death Strike", 49998, 55)
Ability("corpse_explosion", "Corpse Explosion", 49158, 54)
Ability("blood_boil", "Blood Boil", 48721, 57)
Ability("death_and_decay", "Death and Decay", 43265, 59)
Ability("horn_of_winter", "Horn of Winter", 57330, 74)
Ability("scourge_strike", "Scourge Strike", 55090, 66)

Row("blood_strike", 1, 1, 11, 11, 40, "flat_bonus")
Row("blood_strike", 2, 8, 21, 21, 40, "flat_bonus")
Row("blood_strike", 3, 16, 32, 32, 40, "flat_bonus")
Row("blood_strike", 4, 24, 44, 44, 40, "flat_bonus")
Row("blood_strike", 5, 33, 60, 60, 40, "flat_bonus")
Row("blood_strike", 6, 42, 78, 78, 40, "flat_bonus")
Row("blood_strike", 7, 50, 94, 94, 40, "flat_bonus")
Row("death_coil", 1, 1, 18, 18, nil, "base_shadow_damage")
Row("death_coil", 2, 9, 30, 30, nil, "base_shadow_damage")
Row("death_coil", 3, 18, 49, 49, nil, "base_shadow_damage")
Row("death_coil", 4, 27, 70, 70, nil, "base_shadow_damage")
Row("death_coil", 5, 36, 96, 96, nil, "base_shadow_damage")
Row("death_coil", 6, 45, 126, 126, nil, "base_shadow_damage")
Row("death_coil", 7, 52, 153, 153, nil, "base_shadow_damage")
Row("icy_touch", 1, 3, 10, 14, nil, "base_frost_damage_range")
Row("icy_touch", 2, 11, 20, 24, nil, "base_frost_damage_range")
Row("icy_touch", 3, 19, 34, 40, nil, "base_frost_damage_range")
Row("icy_touch", 4, 28, 52, 60, nil, "base_frost_damage_range")
Row("icy_touch", 5, 37, 75, 84, nil, "base_frost_damage_range")
Row("icy_touch", 6, 46, 99, 109, nil, "base_frost_damage_range")
Row("icy_touch", 7, 53, 121, 130, nil, "base_frost_damage_range")
Row("plague_strike", 1, 5, 8, 8, 50, "flat_bonus")
Row("plague_strike", 2, 13, 15, 15, 50, "flat_bonus")
Row("plague_strike", 3, 21, 24, 24, 50, "flat_bonus")
Row("plague_strike", 4, 29, 34, 34, 50, "flat_bonus")
Row("plague_strike", 5, 38, 45, 45, 50, "flat_bonus")
Row("plague_strike", 6, 47, 55, 55, 50, "flat_bonus")
Row("plague_strike", 7, 53, 60, 60, 50, "flat_bonus")
Row("death_strike", 1, 10, 10, 10, 75, "flat_bonus")
Row("death_strike", 2, 18, 20, 20, 75, "flat_bonus")
Row("death_strike", 3, 27, 32, 32, 75, "flat_bonus")
Row("death_strike", 4, 36, 46, 46, 75, "flat_bonus")
Row("death_strike", 5, 45, 61, 61, 75, "flat_bonus")
Row("death_strike", 6, 52, 75, 75, 75, "flat_bonus")
Row("corpse_explosion", 1, 20, 40, 40, nil, "base_shadow_damage")
Row("corpse_explosion", 2, 29, 70, 70, nil, "base_shadow_damage")
Row("corpse_explosion", 3, 38, 100, 100, nil, "base_shadow_damage")
Row("corpse_explosion", 4, 47, 132, 132, nil, "base_shadow_damage")
Row("corpse_explosion", 5, 53, 156, 156, nil, "base_shadow_damage")
Row("blood_boil", 1, 24, 24, 30, nil, "base_shadow_damage_range")
Row("blood_boil", 2, 32, 38, 46, nil, "base_shadow_damage_range")
Row("blood_boil", 3, 41, 54, 64, nil, "base_shadow_damage_range")
Row("blood_boil", 4, 50, 72, 86, nil, "base_shadow_damage_range")
Row("blood_boil", 5, 56, 84, 100, nil, "base_shadow_damage_range")
Row("death_and_decay", 1, 28, 8, 8, nil, "shadow_damage_per_tick")
Row("death_and_decay", 2, 37, 13, 13, nil, "shadow_damage_per_tick")
Row("death_and_decay", 3, 46, 18, 18, nil, "shadow_damage_per_tick")
Row("death_and_decay", 4, 54, 23, 23, nil, "shadow_damage_per_tick")
Row("horn_of_winter", 1, 14, 10, 10, nil, "strength_and_agility")
Row("horn_of_winter", 2, 45, 50, 50, nil, "strength_and_agility")
Row("horn_of_winter", 3, 75, 155, 155, nil, "strength_and_agility")
Row("scourge_strike", 2, 60, 386, 386, nil, "interpolated_native_components")

ProjectRebirthTooltipData = data
