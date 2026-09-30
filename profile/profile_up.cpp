/* profile_up.cpp - Urban Pirate's page in the gmrecomp dev menu.
 *
 * Everything here knows Urban Pirate's own variable and object names, which is
 * why it lives in the game repo and not the toolkit. Where each rule came from
 * (which code entry, what each outcome does) is in docs/cheats.md.
 */
#include "devprofile.h"
#include <imgui.h>
#include <cmath>
#include <cstdio>

extern "C" {
const char *profile_title = "Cheats";
}

/* ---------------- stats ---------------- */

struct Stat { const char *global, *label; double lo, hi, step; };
/* caps are the game's own clamps (controller_lvl_N Step) */
static const Stat stats[] = {
    { "money",     "Money",       0, 1e9, 100 },
    { "food",      "Food",        0, 4,   1 },
    { "energy",    "Energy",      0, 8,   1 },
    { "sanity",    "Sanity",      0, 10,  1 },
    { "hunger",    "Hunger",      0, 4,   1 },
    { "smoke",     "Smoke",       0, 1e9, 5 },
    { "points",    "Street cred", 0, 1e9, 10 },
    { "XP_points", "XP",          0, 1e9, 10 },
};

static void stat_row(const Stat &s) {
    ImGui::PushID(s.global);
    double v = dev_get(s.global);
    ImGui::SetNextItemWidth(110);
    if (ImGui::InputDouble(s.label, &v, s.step, s.step * 10, "%.0f")) dev_set(s.global, fmin(fmax(v, s.lo), s.hi));
    ImGui::SameLine(210);
    bool lock = dev_frozen(s.global);
    if (ImGui::Checkbox("lock", &lock)) dev_freeze(s.global, lock);
    ImGui::PopID();
}

/* ---------------- luck ---------------- */

static bool luck_dumpster, luck_shoplift, luck_social, luck_hitch, luck_paint, luck_dice, luck_skate,
            luck_plant, luck_fight;

static void apply_luck(void) {
    static const char *dumpster[] = { "action_dumpster_result_5", "action_dumpster_result_1",
                                      "action_dumpster_result_2", "action_dumpster_result_3" };
    static const char *shoplift[] = { "action_shoplift_result_1", "action_shoplift_result_4" };
    static const char *social[] = { "action_socialize_result_2", "action_socialize_result_5",
                                    "action_socialize_result_4", "action_socialize_result_1" };
    static const char *hitch[] = { "action_hitch_result_1", "action_hitch_result_4" };
    static const char *fight[] = { "friend_t", "friend_t_2" };
    if (luck_dumpster) dev_luck_prefer("action_dumpster_Alarm_0", dumpster, 4); else dev_luck_clear("action_dumpster_Alarm_0");
    if (luck_shoplift) dev_luck_prefer("action_shoplift_Alarm_0", shoplift, 2); else dev_luck_clear("action_shoplift_Alarm_0");
    if (luck_social) dev_luck_prefer("action_socialize", social, 4); else dev_luck_clear("action_socialize");
    if (luck_hitch) dev_luck_prefer("action_hitchhike_Alarm_0", hitch, 2); else dev_luck_clear("action_hitchhike_Alarm_0");
    if (luck_paint) dev_luck_value("action_paint_train_Other_7", -1); else dev_luck_clear("action_paint_train_Other_7");
    if (luck_fight) dev_luck_prefer("controller_fight", fight, 2); else dev_luck_clear("controller_fight");
    if (luck_plant) { dev_luck_value("action_plant_Create_0", -1); dev_luck_value("action_plant_done_Create_0", +1); }
    else { dev_luck_clear("action_plant_Create_0"); dev_luck_clear("action_plant_done_Create_0"); }
    /* skate contests: your score high, the rivals' low */
    int s[64], n;
    const char *rounds[] = { "round_1_points", "round_2_points", "round_3_points" };
    for (const char *r : rounds) {
        n = dev_sites("controller_skate_competition", r, s, 64);
        for (int k = 0; k < n; k++) if (luck_skate) dev_force_value(s[k], +1); else dev_force(s[k], -1);
        const char *rivals[] = { "_mia", "_nicky", "_snake" };
        for (const char *rv : rivals) {
            char t[64]; snprintf(t, sizeof t, "%s%s", r, rv);
            n = dev_sites("controller_skate_competition", t, s, 64);
            for (int k = 0; k < n; k++) if (luck_skate) dev_force_value(s[k], -1); else dev_force(s[k], -1);
        }
    }
}

/* Dice are craps: 7 or 11 on the first roll wins, later rolls must hit the
 * point. Each roll is two choose(1..6) sites, so set the pair every step. */
static void dice_step(void) {
    int a[4], b[4];
    int na = dev_sites("p1_gamble_roll_1_Other_7", nullptr, a, 4);
    int nb = dev_sites("p1_gamble_roll_2_Other_7", nullptr, b, 4);
    if (!luck_dice) {
        for (int k = 0; k < na; k++) dev_force(a[k], -1);
        for (int k = 0; k < nb; k++) dev_force(b[k], -1);
        return;
    }
    if (na == 2) { dev_force(a[0], 2); dev_force(a[1], 3); }            /* 3 + 4 */
    int point = (int)dev_get("win_point");
    if (nb == 2 && point >= 2 && point <= 12) {
        int d1 = point - 1 > 6 ? 6 : point - 1;
        dev_force(b[0], d1 - 1); dev_force(b[1], point - d1 - 1);
    }
}

/* ---------------- movement ----------------
 * Stock movement: a key press sets a speed once, a release zeroes it, and
 * brushing the coastline stops you dead until you press again. Smooth
 * movement drives the speed from the held keys every step and slides along
 * walls one axis at a time, so the coast never catches you. */

static bool smooth_move = true;
static int p1_obj = -2, walls[3];

static bool blocked(Inst *p, double x, double y) {
    for (int w : walls) {
        if (w < 0) continue;
        for (int k = 0; k < gm_ninsts; k++) if (gm_is(gm_insts[k], w) && gm_collide(p, x, y, gm_insts[k])) return true;
    }
    return false;
}

static void premove(void) {
    if (!smooth_move) return;
    if (p1_obj == -2) {
        p1_obj = dev_object("p1");
        walls[0] = dev_object("sheep_island_mask"); walls[1] = dev_object("shark_city_mask"); walls[2] = dev_object("final_cops");
    }
    Inst *p = dev_first(p1_obj);
    if (!p || dev_get("controls_on") != 0 || dev_get("pause") != 0) return;
    const double spd = 3;
    double dx = (gm_key_down[39] - gm_key_down[37]) * spd, dy = (gm_key_down[40] - gm_key_down[38]) * spd;
    if (dx && blocked(p, p->x + dx, p->y)) dx = 0;
    if (dy && blocked(p, p->x + dx, p->y + dy)) dy = 0;
    p->hspeed = dx; p->vspeed = dy; p->speed = hypot(dx, dy);
    if (dx > 0) p->xscale = -1;
    if (dx < 0) p->xscale = 1;
    dev_set("move", p->speed > 0);
}

/* ---------------- menu ---------------- */

void profile_menu(void) {
    ImGui::SeparatorText("Stats");
    for (const Stat &s : stats) stat_row(s);
    if (ImGui::MenuItem("Refill: energy, food, sanity, not hungry")) {
        dev_set("energy", 5); dev_set("food", 3); dev_set("sanity", 10); dev_set("hunger", 0);
    }
    if (ImGui::MenuItem("+ $500")) dev_set("money", dev_get("money") + 500);

    ImGui::SeparatorText("Luck");
    bool ch = false;
    ch |= ImGui::MenuItem("Dumpster diving finds the good stuff", nullptr, &luck_dumpster);
    ch |= ImGui::MenuItem("Shoplifting always succeeds", nullptr, &luck_shoplift);
    ch |= ImGui::MenuItem("Socializing goes well", nullptr, &luck_social);
    ch |= ImGui::MenuItem("Hitchhiking gets a ride", nullptr, &luck_hitch);
    ch |= ImGui::MenuItem("Train painting never gets caught", nullptr, &luck_paint);
    ch |= ImGui::MenuItem("Fights: your friend shows up", nullptr, &luck_fight);
    ch |= ImGui::MenuItem("Skate contests: judges love you", nullptr, &luck_skate);
    ch |= ImGui::MenuItem("Plants grow fast and big", nullptr, &luck_plant);
    ImGui::MenuItem("Loaded dice", nullptr, &luck_dice);
    if (ch) apply_luck();
    if (ImGui::MenuItem("All of the above")) {
        luck_dumpster = luck_shoplift = luck_social = luck_hitch = luck_paint = luck_fight = luck_skate = luck_plant = luck_dice = true;
        apply_luck();
    }

    ImGui::SeparatorText("Controls");
    ImGui::MenuItem("Smooth movement (hold to move, slide along the coast)", nullptr, &smooth_move);
}

void profile_windows(void) {}

void profile_before_step(void) {
    gm_premove_hook = premove;
    dice_step();
}

void profile_after_step(void) {}
