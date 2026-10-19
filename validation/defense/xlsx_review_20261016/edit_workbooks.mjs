import fs from 'node:fs/promises';
import { SpreadsheetFile, FileBlob } from '@oai/artifact-tool';

const root = 'F:/T8demo/T8-demo-16';
const work = `${root}/validation/defense/xlsx_review_20261016`;
const books = JSON.parse(await fs.readFile(`${work}/edits.json`, 'utf8'));
const letter = i => { let s = ''; for (let n=i+1;n;n=Math.floor((n-1)/26)) s=String.fromCharCode(65+(n-1)%26)+s; return s; };
for (const book of books) {
  const selected = process.argv.find(arg => arg.startsWith('--book='))?.split('=')[1];
  if (selected && !book.name.startsWith(selected)) continue;
  const verifying = process.argv.includes('--verify');
  const wb = await SpreadsheetFile.importXlsx(await FileBlob.load(verifying ? `${root}/data/source/defense_tables/${book.name}` : `${work}/before/${book.name}`));
  if (verifying) {
    for (const spec of book.sheets) {
      const range = spec.name === '填写说明' ? `A${Math.max(1,spec.rows.length-3)}:B${spec.rows.length+1}` : spec.name === '怪物参数' ? 'A102:D107' : 'A1:F5';
      const preview = await wb.render({sheetName:spec.name, range, scale:1, format:'png'});
      await fs.writeFile(`${work}/verified_${book.name.slice(0,2)}_${spec.name}.png`,new Uint8Array(await preview.arrayBuffer()));
    }
    console.log(`[VERIFIED] ${book.name}`);
    continue;
  }
  if (process.argv.includes('--before')) {
    const first = book.sheets[0];
    const preview = await wb.render({sheetName:first.name, range:book.preview, scale:1, format:'png'});
    await fs.writeFile(`${work}/before_${book.name.slice(0,2)}.png`,new Uint8Array(await preview.arrayBuffer()));
    console.log(`[PREVIEW] ${book.name}`);
    continue;
  }
  for (const spec of book.sheets) {
    const sheet = spec.add ? wb.worksheets.add(spec.name) : wb.worksheets.getItem(spec.name);
    // Only the requested main tables and their notes change. Other tabs stay imported.
    for (const table of [...sheet.tables.items]) table.delete();
    const range = `A1:${letter(spec.columns.length-1)}${spec.rows.length+1}`;
    sheet.getUsedRange()?.clear({applyTo:'contents'});
    const values = [spec.columns.map(c=>c.label),...spec.rows];
    const cells = sheet.getRange(range);
    cells.values = values;
    cells.format.font = {name:'Microsoft YaHei',size:11};
    cells.format.verticalAlignment = 'center';
    cells.format.rowHeight = 24;
    const head=sheet.getRange(`A1:${letter(spec.columns.length-1)}1`);
    head.format.fill='#26364A';
    head.format.font={name:'Microsoft YaHei',size:11,bold:true,color:'#FFFFFF'};
    head.format.horizontalAlignment='center';
    head.format.rowHeight=36;
    head.format.wrapText=true;
    sheet.showGridLines=false;
    sheet.freezePanes.freezeRows(1);
    sheet.freezePanes.freezeColumns(1);
    for(let c=0;c<spec.columns.length;c++){
      const def=spec.columns[c];
      const col=sheet.getRange(`${letter(c)}1:${letter(c)}${values.length}`);
      col.format.columnWidth=def.width??Math.min(44,Math.max(16,def.label.length*2+3));
      col.setNumberFormat(def.type==='text'?'@':def.type==='int'?'0':'General');
      if (spec.name==='填写说明' && c===0) col.format.wrapText=true;
      sheet.getRange(`${letter(c)}2:${letter(c)}${values.length}`).format.horizontalAlignment=['int','number'].includes(def.type)?'right':'left';
      if(['description','text'].includes(def.key)){
        col.format.wrapText=true;
        for(let r=0;r<spec.rows.length;r++){
          const text=String(spec.rows[r][c]??'');
          const lines=text.split('\n').reduce((n,line)=>n+Math.max(1,Math.ceil([...line].reduce((sum,ch)=>sum+(ch.charCodeAt(0)>255?2:1),0)/72)),0);
          sheet.getRange(`A${r+2}:${letter(spec.columns.length-1)}${r+2}`).format.rowHeight=Math.min(400,lines*20+8);
        }
      }
    }
    const table=sheet.tables.add(range,true,spec.table.name);
    table.style=spec.table.style;
  }
  wb.recalculate();
  await (await SpreadsheetFile.exportXlsx(wb)).save(`${root}/data/source/defense_tables/${book.name}`);
  for(const spec of book.sheets){
    const renderRange=spec.name==='填写说明'?`A1:B${Math.min(spec.rows.length+1,7)}`:spec.name==='刷怪批次'?'I1:K5':spec.name==='关卡系数'?'A1:F5':spec.name==='怪池成员'?'A1:E6':'A1:F6';
    const preview=await wb.render({sheetName:spec.name,range:renderRange,scale:1,format:'png'});
    await fs.writeFile(`${work}/after_${book.name.slice(0,2)}_${spec.name}.png`,new Uint8Array(await preview.arrayBuffer()));
  }
  console.log(`[OK] ${book.name}`);
}
