import fs from 'node:fs/promises';
import { Workbook, SpreadsheetFile } from '@oai/artifact-tool';

const root = 'F:/T8demo/T8-demo-16';
const work = `${root}/validation/defense/xlsx_config`;
const destination = `${root}/data/source/defense_tables`;
await fs.mkdir(destination, {recursive: true});
const books = JSON.parse(await fs.readFile(`${work}/workbook_payload.json`, 'utf8'));
const parameterNames = Object.fromEntries(`
charge_ms=蓄力时间（毫秒）
copies=弹体数量
spread_degrees=散射角度
blast_bonus=爆炸增伤（%）
radius_bonus=范围增幅（%）
burn_seconds=引燃持续（秒）
ember_seconds=余烬持续（秒）
stun_seconds=眩晕持续（秒）
shield_percent=护盾比例（%）
speed_conversion=攻速转伤害比例
pierce=穿透数量
secondary=追加爆炸
upgraded=升级形态
duration_ms=护甲持续（毫秒）
heal_percent=治疗攻击倍率（%）
heal_bonus=治疗增幅（%）
retaliate_percent=反伤攻击倍率（%）
flower_limit=花灵上限
flower_duration_ms=花灵持续（毫秒）
flower_interval_ms=花灵间隔（毫秒）
flower_radius=花灵范围
flower_damage_percent=花灵伤害倍率（%）
burst_radius=爆发范围
targets=目标数量
slow_ms=减速持续（毫秒）
burst_stun_ms=护盾爆发眩晕（毫秒）
root_ms=花灵缠根持续（毫秒）
guard_ms=守护之森持续（毫秒）
extra_shield=额外护盾开关
slow=减速开关
flowers=花灵开关
burst=爆发开关
self_fallback=无目标时保护自身
follow=迁移花灵开关
armor_status=护甲状态编号
extra_status=额外护盾状态编号
slow_status=减速状态编号
root_status=缠根状态编号
stun_status=眩晕状态编号
guard_status=减伤状态编号
flower_template=花灵模板编号
bonus=伤害增幅（%）
combo_chance=连发概率（%）
knock_chance=击退概率（%）
rain_chance=箭雨概率（%）
knock_distance=击退距离
knock_ms=击退时间（毫秒）
rain_radius=箭雨范围
rain_interval_ms=箭雨间隔（毫秒）
rain_ticks=箭雨次数
rain_ms=箭雨持续（毫秒）
bounce_radius=折射距离
chill_ms=冰冷持续（毫秒）
freeze_ms=冻结持续（毫秒）
rain_freeze_ms=箭雨冻结（毫秒）
focus_ms=集中持续（毫秒）
focus_cap=集中层数上限
chill=冰冷开关
focus=集中开关
damage_percent=伤害倍率（%）
hunt_bonus=追猎增伤（%）
execute_threshold=斩杀阈值（%）
elite_multiplier=精英首领最终倍率
paralyze_ms=麻痹持续（毫秒）
smoke_ms=烟幕持续（毫秒）
fan_ms=刀扇控制持续（毫秒）
shock_ms=感电持续（毫秒）
smoke_radius=烟幕范围
smoke_damage=烟幕伤害倍率（%）
fan_radius=刀扇范围
fan_damage=刀扇伤害倍率（%）
hurt_step=受击减伤增量（%）
hurt_cap=额外减伤上限（%）
hurt_interval_ms=受击计数间隔（毫秒）
lethal_cooldown_ms=免死冷却（毫秒）
immunity_ms=免死保护（毫秒）
control_multiplier=控制持续倍率
knockback_immune=免疫击退
`.trim().split('\n').map(line => line.split('=')));
for (const book of books) {
  if (book.name.startsWith('05_')) book.sheets.find(s => s.name === '填写说明').rows[0][1] = '基础生命、基础攻击和每级增量分列填写，沿用当前成长算法。召唤物另列，不受敌方关卡及刷怪行倍率影响。';
  for (const sheet of book.sheets) {
    if (sheet.columns.map(c => c.key).join(',') === 'id,field,label,path,kind,value') {
      for (const row of sheet.rows) {
        const leaf = String(row[3] ?? '').split('/').at(-1);
        if (parameterNames[leaf]) row[2] = `${row[2]} / ${parameterNames[leaf]}`;
      }
    }
  }
}
function letter(index) {
  let out = '';
  for (let n = index + 1; n; n = Math.floor((n - 1) / 26)) out = String.fromCharCode(65 + (n - 1) % 26) + out;
  return out;
}
for (const book of books) {
  if (process.argv[2] && !book.name.startsWith(process.argv[2])) continue;
  const wb = Workbook.create();
  for (const spec of book.sheets) {
    const sheet = wb.worksheets.add(spec.name);
    const last = letter(spec.columns.length - 1);
    const rows = [spec.columns.map(c => c.label), ...spec.rows];
    const range = sheet.getRange(`A1:${last}${rows.length}`);
    range.values = rows;
    range.format.font = {name: 'Microsoft YaHei', size: 11};
    range.format.rowHeight = 24;
    range.format.verticalAlignment = 'center';
    const head = sheet.getRange(`A1:${last}1`);
    head.format.fill = '#26364A';
    head.format.font = {name: 'Microsoft YaHei', size: 11, bold: true, color: '#FFFFFF'};
    head.format.rowHeight = 36;
    head.format.horizontalAlignment = 'center';
    sheet.showGridLines = false;
    sheet.freezePanes.freezeRows(1);
    sheet.freezePanes.freezeColumns(1);
    for (let c = 0; c < spec.columns.length; c++) {
      const def = spec.columns[c], col = sheet.getRange(`${letter(c)}1:${letter(c)}${rows.length}`);
      const maxLen = Math.max(def.label.length * 2, ...spec.rows.slice(0, 150).map(row => String(row[c] ?? '').length));
      col.format.columnWidth = Math.min(44, Math.max(16, maxLen + 3));
      if (def.key === 'label' && spec.columns.some(c => c.key === 'path')) col.format.columnWidth = 44;
      if (def.key === 'description' || def.key === 'text') col.format.columnWidth = 76;
      if (def.type === 'text') col.setNumberFormat('@');
      if (def.type === 'int') col.setNumberFormat('0');
      if (def.type === 'number') col.setNumberFormat('General');
      if (rows.length > 1) sheet.getRange(`${letter(c)}2:${letter(c)}${rows.length}`).format.horizontalAlignment = ['int','number'].includes(def.type) ? 'right' : 'left';
      if (def.key === 'description') {
        col.format.wrapText = true;
        for (let r = 0; r < spec.rows.length; r++) {
          const text = String(spec.rows[r][c] ?? '');
          const lines = text.split('\n').reduce((sum, line) => sum + Math.max(1, Math.ceil([...line].reduce((n,ch) => n + (ch.charCodeAt(0)>255 ? 2 : 1),0)/70)), 0);
          if (lines > 1) sheet.getRange(`A${r+2}:${last}${r+2}`).format.rowHeight = Math.min(400, 20 * lines + 8);
        }
      }
    }
    if (spec.name === '填写说明') {
      sheet.getRange(`B2:B${rows.length}`).format.wrapText = true;
      sheet.getRange(`A2:B${rows.length}`).format.rowHeight = 62;
    }
    if (spec.columns.map(c => c.key).join(',') === 'id,field,label,path,kind,value') {
      if (spec.rows.length) sheet.getRange(`F2:F${spec.rows.length+1}`).format.numberFormat = spec.rows.map(row => [row[4] === '文本' ? '@' : row[4] === '整数' ? '0' : 'General']);
    }
    if (spec.rows.length) {
      const table = sheet.tables.add(`A1:${last}${rows.length}`, true, `T${books.indexOf(book)}_${book.sheets.indexOf(spec)}`);
    }
  }
  wb.recalculate();
  const file = await SpreadsheetFile.exportXlsx(wb);
  await file.save(`${destination}/${book.name}`);
  console.log(`[OK] ${book.name} sheets=${book.sheets.length} rows=${book.sheets.reduce((n,s)=>n+s.rows.length,0)}`);
  for (let i = 0; i < book.sheets.length; i++) {
    const spec = book.sheets[i];
    const end = spec.name === '填写说明' ? 'B5' : `${letter(Math.min(spec.columns.length - 1, 6))}${Math.min(7, spec.rows.length + 1)}`;
    try {
      const preview = await wb.render({sheetName: spec.name, range: `A1:${end}`, scale: 1, format: 'png'});
      await fs.writeFile(`${work}/preview_${books.indexOf(book)+1}_${i+1}.png`, new Uint8Array(await preview.arrayBuffer()));
    } catch (error) { console.log(`[PREVIEW ERROR] ${book.name}/${spec.name}: ${error.message}`); throw error; }
  }
}
