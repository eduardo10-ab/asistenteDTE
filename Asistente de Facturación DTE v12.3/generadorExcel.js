// generadorExcel.js - V3.6 (Reporte Inventario Agrupado por Producto + Colores)

// =============================================================================
// 1. REPORTE DE INVENTARIO (COSTO PROMEDIO) - AGRUPADO POR PRODUCTO
// =============================================================================
export async function generarKardexExcel(logs, products, metaData) {
    const Excel = window.ExcelJS;
    if (!Excel) { alert("Error CRÍTICO: ExcelJS no cargado."); return; }

    const workbook = new Excel.Workbook();
    const sheet = workbook.addWorksheet('Reporte Inventario', { views: [{ showGridLines: false }] });

    const fechaDescarga = new Date().toISOString().slice(0, 10);
    const nombreArchivoBase = `Reporte_Inventario_${metaData.nombrePerfil}_${fechaDescarga}`;

    // 1. CONFIGURACIÓN DE COLUMNAS (Anchos)
    sheet.columns = [
        { key: 'margin', width: 5 }, 
        { key: 'corr', width: 12 }, 
        { key: 'fecha', width: 18 },
        { key: 'doc', width: 25 }, 
        { key: 'ticket', width: 18 }, 
        { key: 'cliente', width: 30 }, // Cliente movido aquí, producto ya no es columna, es título
        // ENTRADAS (Verde)
        { key: 'ent_cant', width: 10 }, { key: 'ent_prec', width: 12 }, { key: 'ent_tot', width: 14 },
        // SALIDAS (Rojo)
        { key: 'sal_cant', width: 10 }, { key: 'sal_prec', width: 12 }, { key: 'sal_tot', width: 14 },
        // SALDOS (Azul)
        { key: 'bal_cant', width: 12 }, { key: 'bal_cost', width: 12 }, { key: 'bal_tot', width: 15 }
    ];

    // 2. ENCABEZADO GLOBAL DEL DOCUMENTO
    sheet.getRow(1).height = 30;
    sheet.mergeCells('B1:O1'); // Ajustado el merge
    const title = sheet.getCell('B1');
    title.value = nombreArchivoBase.toUpperCase();
    title.font = { bold: true, size: 14 };
    title.alignment = { horizontal: 'center', vertical: 'middle' };

    sheet.getCell('B2').value = `CONTRIBUYENTE: ${metaData.nombrePerfil.toUpperCase()}`;
    sheet.getCell('B3').value = `NIT: ${metaData.nit}`;
    sheet.getCell('B4').value = `PERIODO: ${metaData.periodo}`;
    ['B2','B3','B4'].forEach(c => sheet.getCell(c).font = { bold: true });

    // 3. AGRUPACIÓN DE DATOS POR PRODUCTO
    const productMap = {};
    products.forEach(p => productMap[p.descripcion] = p);

    const movementsByProduct = {};
    // Inicializar grupos
    products.forEach(p => { movementsByProduct[p.descripcion] = []; });
    logs.forEach(log => {
        if (!movementsByProduct[log.producto]) movementsByProduct[log.producto] = [];
        movementsByProduct[log.producto].push(log);
    });

    const productNames = Object.keys(movementsByProduct).sort();
    let globalCorrelativo = 1; // Correlativo continuo o resetear? Usaremos continuo.

    // Estilos constantes
    const HEADER_BORDER_STYLE = { font: { bold: true }, alignment: { horizontal: 'center', vertical: 'middle' }, border: { top: {style:'thin'}, left: {style:'thin'}, bottom: {style:'thin'}, right: {style:'thin'} } };
    const PROD_TITLE_STYLE = { font: { bold: true, size: 12, color: { argb: 'FFFFFFFF' } }, fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF404258' } }, alignment: { horizontal: 'left' } };

    // 4. ITERAR PRODUCTOS Y CREAR TABLAS
    productNames.forEach(pName => {
        const movs = movementsByProduct[pName];
        if (movs.length === 0) return; // Saltar productos sin movimientos

        const prodInfo = productMap[pName] || { codigo: 'S/C' };
        
        // --- A) Título del Producto ---
        const rowTitleIdx = sheet.lastRow ? sheet.lastRow.number + 2 : 6; // Espacio de 2 filas
        const titleRow = sheet.getRow(rowTitleIdx);
        sheet.mergeCells(`B${rowTitleIdx}:O${rowTitleIdx}`);
        const cellTitle = sheet.getCell(`B${rowTitleIdx}`);
        cellTitle.value = `PRODUCTO: [${prodInfo.codigo || 'S/C'}] ${pName}`;
        cellTitle.style = PROD_TITLE_STYLE;

        // --- B) Encabezados de Tabla (Dinamicos por bloque) ---
        const r1 = rowTitleIdx + 1; // Fila superior de encabezados
        const r2 = rowTitleIdx + 2; // Fila inferior de encabezados

        // Fusiones Verticales
        sheet.mergeCells(`B${r1}:B${r2}`); sheet.getCell(`B${r1}`).value = "N°";
        sheet.mergeCells(`C${r1}:C${r2}`); sheet.getCell(`C${r1}`).value = "FECHA";
        sheet.mergeCells(`D${r1}:D${r2}`); sheet.getCell(`D${r1}`).value = "REFERENCIA";
        sheet.mergeCells(`E${r1}:E${r2}`); sheet.getCell(`E${r1}`).value = "TIPO";
        sheet.mergeCells(`F${r1}:F${r2}`); sheet.getCell(`F${r1}`).value = "CLIENTE / PROV."; // Columna ancha

        // Fusiones Horizontales (Secciones de Color)
        sheet.mergeCells(`G${r1}:I${r1}`); sheet.getCell(`G${r1}`).value = "ENTRADAS (+)";
        sheet.mergeCells(`J${r1}:L${r1}`); sheet.getCell(`J${r1}`).value = "SALIDAS (-)";
        sheet.mergeCells(`M${r1}:O${r1}`); sheet.getCell(`M${r1}`).value = "SALDOS (=)";

        // Sub-encabezados
        const subHeaders = ["CANT", "COSTO", "TOTAL", "CANT", "PRECIO", "TOTAL", "CANT", "C.PROM", "TOTAL"];
        let colIdx = 7; // Columna G es la 7
        subHeaders.forEach(h => {
            sheet.getCell(r2, colIdx).value = h;
            colIdx++;
        });

        // Aplicar Estilos y Colores a los Encabezados
        for (let r = r1; r <= r2; r++) {
            sheet.getRow(r).eachCell({ includeEmpty: false }, (cell, col) => {
                cell.style = HEADER_BORDER_STYLE;
                // Colores de Encabezado
                if (col >= 7 && col <= 9) cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFC6EFCE' } }; // Verde
                else if (col >= 10 && col <= 12) cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFC7CE' } }; // Rojo
                else if (col >= 13 && col <= 15) cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFDDEBF7' } }; // Azul
                else if (col >= 2) cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF2F2F2' } }; // Gris
            });
        }

        // --- C) Datos del Producto (Lógica de Costo Promedio) ---
        // IMPORTANTE: Resetear variables por producto
        let saldoU = 0;
        let saldoD = 0;
        let costP = 0;

        movs.sort((a, b) => new Date(a.fecha) - new Date(b.fecha));

        movs.forEach(row => {
            const isEnt = row.tipo === 'ENTRADA';
            const cant = parseInt(row.cantidad) || 0;
            // Para entradas usamos el precio del log o del catálogo actual como fallback
            // Para salidas usamos el costo promedio actual
            const precioEntrada = prodInfo ? parseFloat(prodInfo.precio) : 0; 
            
            let ent_cant=null, ent_prec=null, ent_tot=null;
            let sal_cant=null, sal_prec=null, sal_tot=null;

            if (isEnt) {
                const totalEnt = cant * precioEntrada;
                saldoU += cant;
                saldoD += totalEnt;
                
                ent_cant = cant;
                ent_prec = precioEntrada;
                ent_tot = totalEnt;
            } else {
                const totalSal = cant * costP; // Salida valuada a costo promedio
                saldoU -= cant;
                saldoD -= totalSal;

                sal_cant = cant;
                sal_prec = costP; // Precio de salida es el costo promedio
                sal_tot = totalSal;
            }

            // Recalcular promedio
            if (saldoU > 0 && saldoD > 0) costP = saldoD / saldoU;
            else if (saldoU <= 0) { costP = 0; saldoD = 0; } // Reset si stock es 0

            const rowData = sheet.addRow({
                corr: globalCorrelativo++,
                fecha: new Date(row.fecha).toLocaleString('es-SV'),
                doc: row.referencia || "---",
                ticket: isEnt ? "COMPRA/AJUSTE" : "VENTA",
                cliente: row.cliente || (isEnt ? "PROVEEDOR" : "CLIENTE FINAL"),
                
                ent_cant: ent_cant, ent_prec: ent_prec, ent_tot: ent_tot,
                sal_cant: sal_cant, sal_prec: sal_prec, sal_tot: sal_tot,
                bal_cant: saldoU,   bal_cost: costP,    bal_tot: saldoD
            });

            // Estilos de la fila de datos
            rowData.eachCell({ includeEmpty: true }, (cell, col) => {
                if (col === 1) return;
                cell.border = { top: {style:'thin'}, left: {style:'thin'}, bottom: {style:'thin'}, right: {style:'thin'} };
                
                // Formato Moneda
                if ([8,9, 11,12, 14,15].includes(col)) cell.numFmt = '"$"#,##0.00';

                // Colores de Fondo Suaves para distinguir secciones
                if (col >= 7 && col <= 9) cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFEDF7ED' } }; // Verde pálido
                else if (col >= 10 && col <= 12) cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFEBEE' } }; // Rojo pálido
            });
        });
    });

    descargarExcel(workbook, nombreArchivoBase);
}

// =============================================================================
// 2. NUEVO REPORTE: RESUMEN KARDEX (KARDEX DETALLADO - SIN CAMBIOS)
// =============================================================================
export async function generarReporteKardexDetallado(logs, products, metaData) {
    const Excel = window.ExcelJS;
    if (!Excel) { alert("Error CRÍTICO: ExcelJS no cargado."); return; }

    const workbook = new Excel.Workbook();
    const sheet = workbook.addWorksheet('Resumen Kardex', {
        pageSetup: { orientation: 'landscape', fitToPage: true, fitToWidth: 1, fitToHeight: 0 },
        views: [{ showGridLines: false }]
    });

    sheet.columns = [
        { key: 'margin', width: 3 },     // A
        { key: 'fecha', width: 14 },     // B
        { key: 'tipo', width: 22 },      // C
        { key: 'ref', width: 38 },       // D
        { key: 'cant', width: 10 },      // E
        { key: 'prec', width: 10 },      // F
        { key: 'monto', width: 12 },     // G
        { key: 'desde', width: 15 },     // H
        { key: 'para', width: 30 },      // I
        { key: 'saldo', width: 12 }      // J
    ];

    const TITLE_STYLE = { font: { name: 'Calibri', size: 14, bold: true }, alignment: { horizontal: 'left', vertical: 'middle' } };
    const PROD_HEADER_STYLE = { font: { bold: true, color: { argb: 'FFFF0000' } }, fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFEFEFEF' } }, alignment: { horizontal: 'left' } };
    const TABLE_HEAD_STYLE = { font: { bold: true }, border: { top: {style:'thin'}, left: {style:'thin'}, bottom: {style:'thin'}, right: {style:'thin'} }, alignment: { horizontal: 'center' }, fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFD9D9D9' } } };
    const BORDER = { top: {style:'thin'}, left: {style:'thin'}, bottom: {style:'thin'}, right: {style:'thin'} };

    const fechaHoraGen = new Date().toLocaleString('es-SV');
    const tituloReporte = `Resumen Kardex - ${metaData.nombrePerfil}: ${fechaHoraGen}`;
    const nombreArchivoFinal = `Resumen_Kardex_${metaData.nombrePerfil}_${fechaHoraGen.replace(/[\/:]/g, '-')}`;

    sheet.getCell('A1').value = ""; 
    sheet.mergeCells('B2:J2'); 
    const titleCell = sheet.getCell('B2');
    titleCell.value = tituloReporte;
    titleCell.style = TITLE_STYLE;

    let currentRow = 4;

    const productMap = {};
    products.forEach(p => productMap[p.descripcion] = p);

    const movementsByProduct = {};
    products.forEach(p => { movementsByProduct[p.descripcion] = []; });
    logs.forEach(log => {
        if (!movementsByProduct[log.producto]) movementsByProduct[log.producto] = [];
        movementsByProduct[log.producto].push(log);
    });

    const productNames = Object.keys(movementsByProduct).sort();

    productNames.forEach(pName => {
        const movs = movementsByProduct[pName];
        if (movs.length === 0) return;

        const productInfo = productMap[pName] || { codigo: 'S/C', precio: 0 };
        
        sheet.mergeCells(`B${currentRow}:J${currentRow}`);
        const codeDisplay = productInfo.codigo || 'S/C';
        sheet.getCell(`B${currentRow}`).value = `CODIGO: ${codeDisplay}, DESCRIPCION: ${pName}`;
        sheet.getCell(`B${currentRow}`).style = PROD_HEADER_STYLE;
        currentRow++;

        const headers = ["FECHA", "TIPO DOCUMENTO", "REFERENCIA DOC.", "CANTIDAD", "PRECIO", "MONTO", "DESDE", "PARA", "SALDOS ($)"];
        headers.forEach((h, i) => {
            const cell = sheet.getCell(currentRow, i + 2);
            cell.value = h;
            cell.style = TABLE_HEAD_STYLE;
        });
        currentRow++;

        let saldoAcumulado = 0;
        movs.sort((a, b) => new Date(a.fecha) - new Date(b.fecha));

        movs.forEach(m => {
            const isEntrada = m.tipo === 'ENTRADA';
            const qty = parseInt(m.cantidad) || 0;
            const precio = parseFloat(productInfo.precio || 0);
            const monto = qty * precio;

            if (isEntrada) saldoAcumulado += monto; else saldoAcumulado -= monto;

            let tipoDoc = "Movimiento";
            let para = m.clientName || m.cliente || "CLIENTE FINAL"; 
            let desde = "SUC1";
            const refUpper = (m.referencia || "").toUpperCase();

            if (refUpper.includes("DTE-03") || refUpper.includes("CCF") || refUpper.includes("CREDITO")) tipoDoc = "Crédito Fiscal"; 
            else if (refUpper.includes("DTE-14") || refUpper.includes("SUJETO")) tipoDoc = "Sujeto Excluido"; 
            else if (refUpper.includes("DTE-11") || refUpper.includes("EXPORT")) tipoDoc = "Exportación"; 
            else if (refUpper.includes("DTE-05") || refUpper.includes("NOTA DE CREDITO")) tipoDoc = "Nota de Crédito"; 
            else if (refUpper.includes("DTE-06") || refUpper.includes("NOTA DE DEBITO")) tipoDoc = "Nota de Débito"; 
            else if (m.tipo.includes("AJUSTE")) { tipoDoc = "Ajuste Inventario"; para = "---"; }
            else if (isEntrada) { tipoDoc = "Compra/Carga"; desde = "PROVEEDOR"; para = "SUC1"; }
            else if (refUpper.includes("DTE-01") || refUpper.includes("FAC")) tipoDoc = "Factura";
            else tipoDoc = "Factura"; 

            const rowData = [
                new Date(m.fecha).toLocaleDateString('es-SV'),
                tipoDoc,
                m.referencia || "---",
                qty,
                precio,
                monto,
                desde,
                para,
                saldoAcumulado
            ];

            rowData.forEach((val, i) => {
                const cell = sheet.getCell(currentRow, i + 2);
                cell.value = val;
                cell.border = BORDER;
                cell.alignment = { horizontal: 'center' };
                if([4, 5, 8].includes(i)) cell.numFmt = '"$"#,##0.00';
            });
            currentRow++;
        });
        currentRow += 2;
    });

    descargarExcel(workbook, nombreArchivoFinal);
}

// =============================================================================
// 3. REPORTE DE VENTAS (SIN CAMBIOS)
// =============================================================================
export async function generarReporteVentasExcel(ventas, perfil, periodoTexto) {
    const Excel = window.ExcelJS;
    if (!Excel) { alert("Error CRÍTICO: ExcelJS no cargado."); return; }

    const workbook = new Excel.Workbook();
    const sheet = workbook.addWorksheet('Reporte Ventas', {
        pageSetup: { orientation: 'landscape', fitToPage: true, fitToWidth: 1 }
    });

    let maxCliente = 30;
    ventas.forEach(v => {
        if(v.cliente && v.cliente.length > maxCliente) maxCliente = v.cliente.length;
    });

    sheet.columns = [
        { key: 'margin', width: 3 },     // A
        { key: 'fecha', width: 12 },     // B
        { key: 'hora', width: 10 },      // C
        { key: 'tipo', width: 20 },      // D
        { key: 'cod', width: 38 },       // E 
        { key: 'cli', width: maxCliente + 2 }, // F 
        { key: 'tot', width: 15 },       // G
        { key: 'est', width: 15 }        // H
    ];

    const HEADER_STYLE = { font: { bold: true, color: { argb: 'FFFFFFFF' } }, fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF2A2C3A' } }, alignment: { horizontal: 'center' } };
    const BORDER = { top: {style:'thin'}, left: {style:'thin'}, bottom: {style:'thin'}, right: {style:'thin'} };
    const TITLE_FONT = { size: 16, bold: true };

    const fechaGen = new Date().toLocaleString('es-SV');
    
    sheet.mergeCells('B1:H1'); 
    sheet.getCell('B1').value = `REPORTE DE VENTAS (${perfil.toUpperCase()})`;
    sheet.getCell('B1').font = TITLE_FONT;
    sheet.getCell('B1').alignment = { horizontal: 'center' };

    sheet.mergeCells('B2:H2');
    sheet.getCell('B2').value = `GENERADO: ${fechaGen}`;
    sheet.getCell('B2').alignment = { horizontal: 'center' };

    sheet.mergeCells('B3:H3');
    sheet.getCell('B3').value = `PERIODO MOSTRADO: ${periodoTexto}`;
    sheet.getCell('B3').font = { bold: true };
    sheet.getCell('B3').alignment = { horizontal: 'center' };

    const headers = ["FECHA", "HORA", "TIPO DTE", "COD. GENERACIÓN", "CLIENTE", "TOTAL ($)", "ESTADO"];
    const headerRow = sheet.getRow(5);
    headers.forEach((h, i) => {
        const cell = headerRow.getCell(i + 2);
        cell.value = h;
        cell.style = HEADER_STYLE;
    });

    let granTotal = 0;
    
    ventas.forEach(v => {
        const monto = parseFloat(v.total) || 0;
        const estado = (v.estado || 'PROCESADO').trim();
        if (estado === 'PROCESADO') granTotal += monto;

        const rowValues = [
            v.fecha,
            v.hora,
            v.tipo || "Factura",
            v.codigo || "---",
            v.cliente || "Consumidor Final",
            monto,
            estado
        ];

        const r = sheet.addRow( [null, ...rowValues] ); 

        r.eachCell((cell, col) => {
            if(col === 1) return;
            cell.border = BORDER;
            cell.alignment = { horizontal: 'center' };
            
            if(col === 7) cell.numFmt = '"$"#,##0.00'; 
            if(col === 8) { 
                if(estado === 'PROCESADO') cell.font = { color: { argb: 'FF28A745' }, bold: true };
                else if(estado === 'INVALIDADO') cell.font = { color: { argb: 'FF6C757D' }, bold: true };
                else cell.font = { color: { argb: 'FFDC3545' }, bold: true };
            }
        });
    });

    const totalRow = sheet.addRow([null, "", "", "", "", "TOTAL GENERAL:", granTotal, ""]);
    totalRow.getCell(6).font = { bold: true }; 
    totalRow.getCell(7).font = { bold: true }; 
    totalRow.getCell(7).numFmt = '"$"#,##0.00';
    totalRow.getCell(7).border = BORDER;

    const safeName = `Reporte de Ventas (${perfil}) (${fechaGen.replace(/[\/:]/g, '-')})`;
    descargarExcel(workbook, safeName);
}

async function descargarExcel(workbook, nameBase) {
    const buffer = await workbook.xlsx.writeBuffer();
    const blob = new Blob([buffer], { type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = `${nameBase}.xlsx`;
    link.click();
}