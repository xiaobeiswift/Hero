class_name SectProgressUI
extends RefCounted
var host
func _init(owner) -> void:host=owner
func show() -> void:
	var s=host.state
	if s.sect_trial_won and s.sect_rank==1:
		victory();return
	if s.sect=="未入门":
		host._modal("岑远 · 代试游师","练武堂南庭 / 门中功课","‘门派不是换一身衣服。你得知道，自己的招式护得住什么。’\n\n先走完陆伯的荐帖机缘，再来谈哪一家的考法。")
		return
	if s.sect_rank>=2:
		host._modal("岑远","内门功课 / 已验其艺","‘你的本门功夫，已经用在该用的地方。’\n\n内门荐记已领，不必重复受试。继续磨练招式，或去江湖里看看，功夫能替谁解一场困。",[["研读武学",host._show_martials],["告辞",host._close_modal]],true)
		return
	var body="岑远替三家门派代验初学。赢下切磋只是其一，还须在实战中验明本门的用意。\n\n[color=#d3b276]%s · 本门考法[/color]\n%s\n\n要求3级。受试前免费调息，并自动换上本门招式。\n通过后可领取内门荐记：真气上限 +1、防御 +1、考绩 +3。" % [s.sect,s.sect_trial_requirement()]
	host._modal("岑远 · 代试游师","门派机缘 / 以艺立身",body,[["开始受试",begin],["研读武学",host._show_martials],["告辞",host._close_modal]],true)
func begin() -> void:
	if not host.state.can_take_sect_trial():
		host._toast("至少3级且须已入门；已有待领取考绩时，请先领荐记。")
		return
	host.state.heal_rest()
	host.state.equip_art(host.state.sect_art())
	host._start_battle("sect_trial")
func victory() -> void:
	if host.state.sect_trial_won:
		host._modal("门中考法已明","门派机缘 / 内门荐记","岑远收势，提笔在荐帖上添了一行字。\n\n‘招式的名字并不稀奇，知道何时、为何而用，才算往里走了一步。’\n\n[color=#d3b276]领取后晋为内门弟子：真气上限 +1、防御 +1、考绩 +3。[/color]\n即便暂时离开，已通过的考绩也会保留。",[["领取内门荐记",promote],["稍后领取",host._close_modal]],true)
	else:
		host._modal("胜负之外，还须验艺","门派机缘 / 仍可重试","‘这场切磋你赢了，可本门的考法还未验全。’\n\n"+host.state.sect_trial_requirement()+"\n\n本次切磋的修为与铜钱已结算；晋升须满足考法，重复领奖不会叠加永久属性。",[["再试一次",begin],["先去练习",host._close_modal]],true)
func promote() -> void:
	if host.state.complete_sect_trial():
		host._close_modal()
		host._toast("晋为内门弟子 · 真气上限 +1、防御 +1、考绩 +3。")
	else:host._toast("这份荐记已经领取，或考法尚未通过。")
