extends Object

# AGENT: Copy-snippet source for the playground and COOKBOOK checks.
# INVARIANT: for_key(type_name) is non-empty for every TaRegistry type.
# DO NOT: Persist. Do not invent APIs the widgets do not have.

const SNIPPETS := {
	"TaButton":
		"var play := TaButton.new()  # hover, focus, press, sound; ui_accept presses it
play.text = \"Play\"
play.press_sound = &\"confirm\"
add_child(play)
# class MyButton extends TaButton keeps all of it",
	"TaWorldAttach":
		"var plate := TaWorldAttach.new()  # BILLBOARD in the world, or SCREEN on the canvas\nplate.position = Vector3(0, 2.2, 0)\nenemy.add_child(plate)\nvar hp := TaBar.new()\nhp.set_range(60, 100)\nplate.add_content(hp)  # the same TaBar as the HUD strip, same look",
	"TaPopover":
		"var card := TaPopover.new()\nadd_child(card)\ncard.safe_insets = Vector4(8, 64, 96, 8)  # clear of HUD row and rail\ncard.keep_clear = pots  # AUTO avoids covering the other pots\ncard.get_content().add_child(plant_panel)\npot.pressed.connect(func() -> void: card.open(pot))  # Esc or a click elsewhere closes",
	"TaOverlay":
		"var layer := TaOverlay.new()\nadd_child(layer)\nmy_panel.z_index = 1  # above the dimmer\nlayer.add_child(my_panel)\nlayer.open()  # Esc closes; override handle_cancel() for more",
	"TaCancelRouter":
		"var router := TaCancelRouter.new()\nadd_child(router)\nrouter.push(phone, phone.close)  # your own panel\nrouter.push(selection, clear_selection, true)  # under every overlay\n# Esc: top open overlay first, then pause.tscn (or router.fallback)",
	"TaRadial ring":
		"var dial := TaRadial.new()\ndial.set_ring_width(6)\ndial.set_center_text(\"72%\")\ndial.set_value(72)\nadd_child(dial)",
	"TaBadge.attach":
		"TaBadge.attach(phone_button, \"3\")\nTaJuice.pulse(ready_slot)\n# Later: attach(phone_button, \"\") hides it. TaJuice.stop_pulse(ready_slot)",
	"TaDangerQuiet":
		"var reset := Button.new()\nreset.text = \"New game\"\nreset.theme_type_variation = \"TaDangerQuiet\"\nadd_child(reset)",
	"Text styles":
		"var note := RichTextLabel.new()\nnote.bbcode_enabled = true\nnote.fit_content = true\nnote.text = \"[b]Bold[/b] [s]done[/s]\"\nadd_child(note)\n# Italic needs a real face: look.face_italic = preload(\"res://fonts/italic.ttf\")",
	"TaModal page":
		"var page := TaModal.new()\npage.title = \"Journal\"\npage.confirm_text = \"\"\npage.closable = true\nadd_child(page)\npage.get_content().add_child(journal_list)\npage.show_modal()",
	"TaBadge":
		"var badge := TaBadge.new()\nbadge.text = \"New\"\nbadge.tone = TaBadge.Tone.ACCENT\nadd_child(badge)",
	"TaToastHost":
		"var host := TaToastHost.new()\nadd_child(host)\nhost.show_message(\"Saved\")",
	"TaToast":
		"var toast := TaToast.new()\ntoast.text = \"Saved\"\nadd_child(toast)",
	"TaDialog":
		"var d := TaDialog.new()\nd.title = \"Prestige?\"\nd.body = \"Wipe crumbs?\"\nadd_child(d)\nd.confirmed.connect(_on_wipe)\nd.show_dialog()",
	"TaModal":
		"var sheet := TaModal.new()\nsheet.title = \"Day complete\"\nsheet.body = \"The grove is quiet.\"\nsheet.z_index = 40\nadd_child(sheet)\nsheet.confirmed.connect(_on_ok)\nsheet.show_modal()",
	"TaItemTooltip":
		"var tip := TaItemTooltip.new()\ntip.title = \"Sword\"\ntip.body = \"A blade.\"\ntip.attach(hover_target)",
	"TaSlot":
		"var slot := TaSlot.new()\nslot.tooltip_title = \"Gem\"\nslot.badge_text = \"3\"\nadd_child(slot)",
	"TaWindow":
		"var win := TaWindow.new()\nwin.title = \"Inspector\"\nwin.get_content().add_child(Label.new())\nadd_child(win)",
	"TaSlotGrid":
		"var grid := TaSlotGrid.new()\ngrid.grid_columns = 4\ngrid.slot_count = 8\nadd_child(grid)",
	"TaInspector":
		"var inspect := TaInspector.new()\ninspect.add_row(\"Name\", LineEdit.new())\nadd_child(inspect)",
	"TaInfoPopup":
		"var info := TaInfoPopup.new()\nadd_child(info)\ninfo.popup_message(\"Hover help.\", anchor)",
	"TaTabWindow":
		"var tabs := TaTabWindow.new()\ntabs.title = \"Loadout\"\ntabs.add_page(\"Stats\", Label.new())\nadd_child(tabs)",
	"TaTransition":
		"TaTransition.on(self).fade_through()\n# TaTransition.on(self).wipe_through()\n# TaTransition.on(self).through()",
	"TaPromptHint":
		"var hint := TaPromptHint.new()\nadd_child(hint)",
	"TaRebindRow":
		"var row := TaRebindRow.new()\nrow.action = &\"ui_accept\"\nadd_child(row)",
	"TaChip":
		"var chip := TaChip.new()\nchip.set_caption(\"AMMO\")\nchip.set_pair(30, 90)\nadd_child(chip)",
	"TaBar":
		"var bar := TaBar.new()\nbar.set_caption(\"HP\")\nbar.set_range(72, 100)\nadd_child(bar)",
	"TaInfoIcon":
		"var info := TaInfoIcon.new()\ninfo.title = \"Hint\"\ninfo.body = \"Click for TaInfoPopup.\"\nadd_child(info)",
	"TaTag":
		"var tag := TaTag.new()\ntag.text = \"Quest\"\ntag.dismissible = true\nadd_child(tag)",
	"TaHeaderPanel":
		"var panel := TaHeaderPanel.new()\npanel.title = \"Loadout\"\npanel.get_content().add_child(Label.new())\nadd_child(panel)",
	"TaButtonRow":
		"var row := TaButtonRow.new()\nrow.set_captions(PackedStringArray([\"Save\", \"Load\"]))\nadd_child(row)",
	"TaPlateButton":
		"var plate := TaPlateButton.new()\nplate.set_plate(spin_texture)\nplate.disabled = true\nadd_child(plate)",
	"TaButtonCol":
		"var col := TaButtonCol.new()\ncol.set_captions(PackedStringArray([\"Resume\", \"Options\"]))\nadd_child(col)",
	"TaToggleGroup":
		"var group := TaToggleGroup.new()\ngroup.add_option(\"Low\")\ngroup.add_option(\"High\")\nadd_child(group)",
	"TaVBar":
		"var vbar := TaVBar.new()\nvbar.set_caption(\"MP\")\nvbar.set_value(40)\nadd_child(vbar)",
	"TaRadial":
		"var radial := TaRadial.new()\nradial.set_caption(\"XP\")\nradial.set_value(72)\nadd_child(radial)",
	"TaSortList":
		"var sort := TaSortList.new()\nsort.set_items(PackedStringArray([\"Oak\", \"Ash\"]))\nadd_child(sort)",
	"TaReorderList":
		"var list := TaReorderList.new()\nlist.set_items(PackedStringArray([\"First\", \"Second\"]))\nadd_child(list)",
	"TaIconGrid":
		"var icons := TaIconGrid.new()\nicons.grid_columns = 4\nicons.cell_count = 8\nadd_child(icons)",
	"TaFieldRow":
		"var row := TaFieldRow.new()\nrow.caption = \"Name\"\nrow.set_field(LineEdit.new())\nadd_child(row)",
	"TaInteractHint":
		"var hint := TaInteractHint.new()\nhint.set_prompt(\"E\", \"Open chest\")\nadd_child(hint)",
	"TaKillFeed":
		"var feed := TaKillFeed.new()\nadd_child(feed)\nfeed.push_line(\"Eliminated cube\")",
	"TaReticle":
		"var reticle := TaReticle.new()\nadd_child(reticle)\nreticle.ping_hit()",
	"TaVignette":
		"var vig := TaVignette.new()\nadd_child(vig)\nvig.flash(1.0)",
	"TaHotbar":
		"var bar := TaHotbar.new()\nbar.slot_count = 8\nadd_child(bar)",
	"TaMinimap":
		"var map := TaMinimap.new()\nadd_child(map)\n# map.get_content().add_child(your_viewport)",
	"TaPartyFrame":
		"var frame := TaPartyFrame.new()\nframe.set_member_name(\"Ally\")\nframe.set_health(70)\nadd_child(frame)",
	"TaSpeechBubble":
		"var bubble := TaSpeechBubble.new()\nbubble.set_text(\"Pay the debt.\")\nadd_child(bubble)",
	"TaShopCard":
		"var card := TaShopCard.new()\ncard.set_title(\"Spud SMG\")\ncard.set_price(\"$22\")\nadd_child(card)",
	"TaStatRow":
		"var row := TaStatRow.new()\nrow.set_stat(\"Damage\", 8)\nadd_child(row)",
	"TaChoicePicker":
		"var pick := TaChoicePicker.new()\npick.set_heading(\"Level up\")\npick.set_choice(0, \"Berserk\", \"+8 Damage\")\nadd_child(pick)",
	"TaWinSplash":
		"var splash := TaWinSplash.new()\nsplash.set_amount(\"+54\")\nsplash.present()\nadd_child(splash)",
	"TaBanner":
		"var banner := TaBanner.new()\nbanner.set_title(\"WAVE 3\")\nbanner.set_sub(\"12\")\nadd_child(banner)",
	"TaBuffStrip":
		"var buffs := TaBuffStrip.new()\nbuffs.set_buff(0, \"Haste\")\nadd_child(buffs)",
	"TaStepper":
		"var bet := TaStepper.new()\nbet.set_value(5)\nadd_child(bet)",
	"TaQuestTracker":
		"var quest := TaQuestTracker.new()\nquest.set_objectives(PackedStringArray([\"Clear the crypt\"]))\nadd_child(quest)",
	"TaCompass":
		"var compass := TaCompass.new()\ncompass.set_bearing(20)\nadd_child(compass)",
	"TaScoreboard":
		"var board := TaScoreboard.new()\nboard.set_rows(PackedStringArray([\"You\"]), PackedStringArray([\"12\"]))\nadd_child(board)",
	"TaFloater":
		"TaFloater.pop(hud, \"+12 gold\", Vector2(80, 80))",
	"TaHighlightCell":
		"var cell := TaHighlightCell.new()\ncell.set_selected(true)\nadd_child(cell)",
	"Button":
		"var button := Button.new()\nbutton.text = \"OK\"\nadd_child(button)",
	"OptionButton":
		"var options := OptionButton.new()\noptions.add_item(\"Alpha\")\noptions.add_item(\"Beta\")\nadd_child(options)",
	"PauseOverlay":
		"var pause := preload(\"res://addons/theme_assist/scenes/pause.tscn\").instantiate()\nadd_child(pause)\npause.resume_pressed.connect(_on_resume)",
	"HudStrip":
		"var hud := preload(\"res://addons/theme_assist/scenes/hud.tscn\").instantiate()\nadd_child(hud)\nhud.get_toast_host().show_message(\"Hi\")",
	"OptionsPanel":
		"var options := preload(\"res://addons/theme_assist/scenes/options.tscn\").instantiate()\nadd_child(options)",
	"TaFanfare":
		"TaFanfare.celebrate(score)\nTaFanfare.deny(panel)\nTaSfx.play_on(self, TaSfx.confirm())",
	"TaTitle":
		"label.theme_type_variation = \"TaTitle\"\n# TaCaption, TaDanger, TaSuccess, TaWarning",
}


static func for_key(key: String) -> String:
	if SNIPPETS.has(key):
		return String(SNIPPETS[key]).strip_edges()
	return ""


static func keys() -> PackedStringArray:
	var out := PackedStringArray()
	for key in SNIPPETS.keys():
		out.append(String(key))
	return out
