-- Player-facing copy only. Protocol identities, tuning and audit fields stay intact.
ProjectRebirthSkillPresentation = {}
local P = ProjectRebirthSkillPresentation
local catalog, catalogSource
function P.Entry(id)
    if catalogSource ~= ProjectRebirthGlossaryData or not catalog then
        catalog, catalogSource = {}, ProjectRebirthGlossaryData
        for _, entry in ipairs(catalogSource or {}) do catalog[entry.id] = entry end
    end
    return catalog[tonumber(id)]
end

function P.Name(id, fallback)
    local entry = P.Entry(id)
    -- Restore names shortened by the wire field, without overriding a renamed server Skill.
    if entry and (not fallback or fallback == "" or entry.name:sub(1, #fallback) == fallback) then return entry.name end
    return fallback or "Unknown Skill"
end

local function Trim(text)
    local clean = text:gsub("^%s+", ""):gsub("%s+$", "")
    return clean
end

-- These describe the same catalog effects, without turning internal tags into
-- player requirements or inventing amounts for an unspecified secondary bonus.
-- {value} is always read from the existing Rank I/V pair, never new tuning.
local naturalWording = {
    ["Rune recovery time improved."] = "Reduces the time your runes take to recover by {value}.",
    ["Loss-of-control duration reduced."] = "Reduces the duration of effects that cause you to lose control of your character by {value}.",
    ["Stun duration reduced."] = "Reduces the duration of Stun effects on you by {value}.",
    ["Fear duration reduced."] = "Reduces the duration of Fear effects on you by {value}.",
    ["Root duration reduced."] = "Reduces the duration of movement-immobilizing effects on you by {value}.",
    ["Silence duration reduced."] = "Reduces the duration of Silence effects on you by {value}.",
    ["Spell Penetration increased."] = "Increases your spell penetration by {value}.",
    ["Parry chance increased."] = "Increases your chance to parry by {value} while you are able to parry.",
    ["Block chance increased."] = "Increases your chance to block by {value} while a shield is equipped.",
    ["Block Value increased."] = "Increases the amount of damage blocked by your shield by {value}.",
    ["Effective Stealth improved."] = "Makes you harder to detect while stealthed.",
    ["Stealth detection improved."] = "Improves your ability to detect stealthed enemies.",
    ["Mounted speed increased."] = "Increases your mounted movement speed by {value}.",
    ["Swim speed increased."] = "Increases your swimming speed by {value}.",
    ["Falling damage reduced."] = "Reduces the damage you take from falling by {value}.",
    ["Healing performed on self increased."] = "Increases the healing you do to yourself by {value}.",
    ["Absorb effects increased."] = "Increases the amount of damage absorbed by your absorption effects by {value}.",
    ["Healing done increased."] = "Increases the healing you do by {value}.",
    ["Healing received increased."] = "Increases the healing you receive by {value}.",
    ["Pet/minion Hit increased."] = "Increases your permanent pet's chance to hit by {value}.",
    ["Additional miscellaneous-material drop opportunity increased."] = "Increases your chance to find additional materials on qualifying enemies by {value}.",
    ["Alchemy extra output/reagent conservation opportunity increased."] = "Increases your chance to produce extra items or conserve reagents with Alchemy by {value}.",
    ["Blacksmithing extra output/reagent conservation opportunity increased."] = "Increases your chance to produce extra items or conserve reagents with Blacksmithing by {value}.",
    ["Cooking output/effectiveness increased."] = "Improves the quantity and effectiveness of food you prepare with Cooking by {value}.",
    ["Consecutive successful weapon hits build attack speed, up to the rank cap."] = "Consecutive successful weapon hits increase your attack speed by up to {value}.",
    ["Consecutive spell casts build Spell Haste, up to the rank cap."] = "Consecutive spell casts increase your spell haste by up to {value}.",
    ["Leaving combat below 50% Health restores a percentage of maximum Health over time."] = "Leaving combat while below 50% health restores {value} of your maximum health over time.",
    ["Dodge, Parry, or Block empowers the next direct damaging attack."] = "After you dodge, parry or block, your next direct damaging attack deals {value} additional damage.",
    ["Resisting or absorbing hostile magic empowers the next eligible spell."] = "Resisting or absorbing hostile magic empowers your next eligible spell.",
    ["Repeatedly casting the same spell reduces its Mana cost up to the rank cap."] = "Repeatedly casting the same spell reduces its mana cost by up to {value}.",
    ["Killing blows restore a percentage of the appropriate combat resource."] = "Qualifying killing blows restore {value} of your combat resource.",
    ["Moving toward a hostile target grants Movement Speed."] = "Increases your movement speed by {value} while you continue moving toward an enemy.",
    ["You and your active pet/minion deal increased damage while attacking the same target."] = "You and your pet deal {value} additional damage while attacking the same target.",
    ["Dual-wield Attack Speed and off-hand effectiveness increase."] = "Increases your attack speed and the effectiveness of your off-hand weapon while dual wielding.",
    ["While using a shield, Healing Received and Block Value are increased."] = "While a shield is equipped, increases the healing you receive and the amount of damage you block.",
    ["Maximum Mana and magical resistances increased."] = "Increases your maximum mana by {value} and your magical resistances.",
    ["Repeated damage from one school builds adaptation against that school, up to the rank cap."] = "Repeated damage from the same school reduces the damage you take from that school by up to {value}.",
    ["Against targets below 25% Health, gain substantial Critical Strike chance and Critical Damage."] = "Increases your critical strike chance and critical strike damage against targets below 25% health.",
    ["Consecutive successful direct attacks or spells build Haste; miss/avoidance/major interruption breaks the chain."] = "Consecutive successful direct attacks or spells increase your haste. A miss, an avoided attack or a major interruption breaks the chain.",
    ["All equipped weapon damage increases substantially and grants a modest Hit/Expertise benefit appropriate to the weapon."] = "Increases the damage of your equipped weapons and grants additional hit or expertise appropriate to the weapon.",
    ["All magical schools gain increased damage and Spell Penetration."] = "Increases your magical damage and spell penetration.",
    ["Mana regenerated while already at maximum Mana builds a temporary Spell Power reserve."] = "Mana regenerated while at full mana grants a temporary spell power bonus.",
    ["At low Health, gain damage reduction and crowd-control resistance."] = "At low health, reduces damage taken and increases your resistance to crowd control.",
    ["Continuously advancing toward enemies builds Physical Damage and Movement Speed."] = "Continuously moving toward enemies increases your physical damage and movement speed.",
    ["Owner and permanent pet share a portion of certain temporary offensive bonuses."] = "You and your permanent pet share a portion of certain temporary offensive bonuses.",
    ["All healing increases while healing-spell resource costs decrease."] = "Increases your healing and reduces the resource cost of your healing spells.",
    ["Below 20% Health, gain increased Healing Received and Damage Reduction."] = "While below 20% health, increases the healing you receive and reduces damage taken.",
    ["Provides meaningful efficiency/output bonuses across gathering and crafting professions."] = "Improves the efficiency and yield of your gathering and crafting professions.",
    ["Spell Power and maximum Mana increased."] = "Increases your spell power by {value} and your maximum mana.",
    ["At manifestation, selects one valid primary attribute using the weighted Attribute Affinity system. That attribute gains increased effectiveness; selection is locked for this incarnation."] = "When this Skill manifests, one of your primary attributes is chosen based on your affinity. Increases that attribute's effectiveness by {value} for this Life.",
    ["At manifestation, selects one valid primary attribute using the weighted Attribute Affinity system. Increases that attribute's effectiveness and partially converts otherwise-wasted eligible over-cap secondary rating into useful primary-attribute benefit."] = "When this Skill manifests, one of your primary attributes is chosen based on your affinity. Increases that attribute's effectiveness by {value} and converts a portion of eligible secondary rating above its cap into a bonus to that attribute.",
}

local function StatWording(text)
    text = text:gsub("^All ", "")
    text = text:gsub("Generic Spell Power", "spell power"):gsub("All standard magical resistances", "magical resistances")
    text = text:gsub("Melee/ranged attack speed", "melee and ranged attack speed")
    text = text:gsub("Pet/minion attack/cast speed", "permanent pet's attack and casting speed")
    text = text:gsub("Pet/minion", "permanent pet's"):gsub("Pet Health and Armor", "permanent pet's health and armor")
    text = text:gsub("Hit chance", "chance to hit"):gsub("Critical Strike chance", "critical strike chance")
    text = text:gsub("Critical Damage", "critical strike damage"):gsub("Critical damage", "critical strike damage")
    text = text:gsub("Movement Speed", "movement speed"):gsub("Attack Power", "attack power")
    text = text:gsub("Spell Power", "spell power"):gsub("Spell Haste", "spell haste")
    text = text:gsub("Maximum Health", "maximum health"):gsub("Maximum Mana", "maximum mana")
    text = text:gsub("Health", "health"):gsub("Mana", "mana"):gsub("Energy", "energy"):gsub("Rage", "rage")
    text = text:gsub("Runic Power generated", "runic power generation"):gsub("Runic Power", "runic power")
    text = text:gsub("Attack Speed", "attack speed"):gsub("Critical Strike", "critical strike")
    text = text:gsub("Armor", "armor"):gsub("Penetration", "penetration")
    text = text:gsub("Rating", "rating"):gsub("Resistance", "resistance")
    text = text:gsub("One%-Handed", "one-handed"):gsub("Two%-Handed", "two-handed")
    text = text:gsub("Fist Weapon", "fist weapon"):gsub("Sword", "sword"):gsub("Axe", "axe"):gsub("Mace", "mace")
    return text:sub(1, 1):lower() .. text:sub(2)
end

local function RankCopy(body, low, high)
    local first, unit = low:match("^([%d%.]+)%s+([%a_]+)$")
    local last, lastUnit = high:match("^([%d%.]+)%s+([%a_]+)$")
    local value
    if first and last and unit == lastUnit then
        value = first == last and first or first .. "–" .. last
        if unit:find("percent", 1, true) then value = value .. "%" end
    end
    local authored = naturalWording[body]
    if authored and (value or not authored:find("{value}", 1, true)) then
        return authored:gsub("{value}", function() return value end)
    end
    if not value then
        -- Empty/nonnumeric rank rows in this catalog repeat condition tags, not
        -- rank effects. Keep the actual effect and discard the duplicate labels.
        if low == high then return body end
        return body .. "\n\nAt rank 1: " .. low .. ". At rank 5: " .. high .. "."
    end
    if unit == "percent_damage" then
        local damage, secondary = body:match("^(.-) damage and (.-) increased%.$")
        if not damage then damage, secondary = body:match("^(.-) damage increased and (.-) increased%.$") end
        if damage then return "Increases your " .. StatWording(damage) .. " damage by " .. value .. " and your " .. StatWording(secondary) .. "." end
    end
    local stat, suffix = body:match("^(.-) increased(.-)%.$")
    local verb = "Increases"
    if not stat then stat, suffix = body:match("^(.-) reduced(.-)%.$"); verb = "Reduces" end
    if stat then
        suffix = suffix:gsub(" substantially", "")
        stat = stat:gsub(" both$", "")
        return verb .. " your " .. StatWording(stat) .. " by " .. value .. StatWording(suffix) .. "."
    end
    -- Preserve an unfamiliar numeric effect instead of guessing its meaning.
    return body .. "\n\n" .. value .. " " .. unit:gsub("_", " ") .. "."
end

function P.Clean(text)
    text = tostring(text or ""):gsub("\r", "")
    text = text:gsub("%[Closed Alpha:[^%]]*%]", "")
    local lines = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        -- Condition tags are authoring metadata. Meaningful triggers and
        -- equipment requirements are already in the effect (or wording above).
        if not line:match("^%s*Conditions?:") then
            line = line:gsub("^%s*Gain:%s*", ""):gsub("^%s*Scaling:%s*", ""):gsub("^%s*Reset:%s*", "")
            lines[#lines+1] = line
        end
    end
    text = Trim(table.concat(lines, "\n")):gsub("\n%s*\n%s*\n", "\n\n")
    local body, low, high = text:match("^(.-)%s*Rank I:%s*(.-)%. Rank V:%s*(.-)%.%s*$")
    if body then text = RankCopy(Trim(body), Trim(low), Trim(high)) end
    text = text:gsub("%f[%a]ICD%f[%A]", "cooldown")
    text = text:gsub("percentage_points", "percentage points")
    return Trim(text)
end

function P.Effect(id)
    local entry = P.Entry(id)
    if entry and entry.description and entry.description ~= "" then return P.Clean(entry.description) end
    local skill = ProjectRebirthSkillData and ProjectRebirthSkillData[tonumber(id)]
    if skill and skill.ranks and skill.ranks[1] then return P.Clean(skill.ranks[1].text) end
    -- The protocol's 64-byte preview is not a complete effect. Never present it as one.
    return "The full description is unavailable. Update your client before choosing this Skill."
end

function P.Meta(rarity, tier)
    return tostring(rarity) .. "  •  " .. (tonumber(tier) and tonumber(tier) > 0 and "Tier " .. tier or "Tier unknown")
end

-- Retain a small diagnostic ring for support, but keep legacy acquisition dumps
-- out of normal chat. Never filter player chat, payouts, quest rewards or errors.
P.Diagnostics = {}
local diagnosticUntil, diagnosticId = 0, nil
function P.ChatFilter(_, _, message)
    if not GetRealmName or GetRealmName() ~= "Rebirth" then return false end
    local plain = tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local now = GetTime and GetTime() or 0
    local id = plain:match("^Manifestation choice %d+: .+ %(ID (%d+), rarity %d+%)%.$")
    local hide = plain:match("^Rebirth Skill status: [%w_]+; slots %d+/%d+%.$") ~= nil
    if id then diagnosticId, diagnosticUntil, hide = tonumber(id), now + 3, true end
    if plain:find("Use the Rebirth choice popup to claim one Skill,", 1, true) == 1 then hide = true end
    if now <= diagnosticUntil and diagnosticId then
        local entry = P.Entry(diagnosticId)
        local first = entry and entry.description:match("^[^\n]+")
        if plain:match("^Gain:") or plain:match("^Scaling:") or plain:match("^Reset:")
            or plain:match("^Rank [I1] test value:") or plain:match("^%[Closed Alpha:")
            or (first and plain == first) then hide = true end
    end
    if hide then
        if P.Diagnostics[#P.Diagnostics] ~= message then
            P.Diagnostics[#P.Diagnostics+1] = message
            if #P.Diagnostics > 50 then table.remove(P.Diagnostics, 1) end
        end
        return true
    end
    return false
end
if ChatFrame_AddMessageEventFilter then ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", P.ChatFilter) end
