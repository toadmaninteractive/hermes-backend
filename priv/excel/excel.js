"use strict"

// -----------------------------------------------------------------------------

const HOST = "0.0.0.0"
const PORT = parseInt(process.env.PORT || 4999, 10)

// -----------------------------------------------------------------------------

const Excel = require("exceljs")
const fs = require("fs").promises
const {createServer} = require("http")
const {parse: parseUrl} = require("url")

// -----------------------------------------------------------------------------

const server = createServer(async (req, res) => {

  const read = async (stream) => {
    const chunks = []
    for await (const chunk of stream) chunks.push(chunk)
    return Buffer.concat(chunks).toString("utf8")
  }

  const respond = (code, type, body) => {
    res.setHeader("content-type", type)
    res.writeHead(code)
    if (typeof body !== "undefined") {
      res.end(body)
    }
  }

  try {

    const {method, url} = req
    const {pathname, query} = parseUrl(url, true)

    if (pathname === "/generate") {
      const data = JSON.parse(await read(req))
      // console.debug("+REQ", data)
      const {officeName, dateFrom, dateTo, items} = data

      const daysInMonth = ((new Date(dateTo) - new Date(dateFrom)) / 1000 / 3600 / 24) + 1

      const wb = new Excel.Workbook()
      await wb.xlsx.readFile("visma.xlsx")
      const ws = wb.getWorksheet("EG7")

      // // remove sample rows
      // // TODO: get rid of this by providing clean source file!
      // ws.spliceRows(11, 12)

      // insert actual rows
      items.reverse().map(({uid, name, time_offs}, index) => {
        const row = [uid, name]
        for (let k in time_offs) {
          row[parseInt(k, 10) + 1] = time_offs[k] || ""
        }
        // NB: 11 is specific for "visma.xlsx"
        // console.debug("+ROW", row)
        ws.insertRow(11, row)
        ws.getRow(11).height = 20
        ws.getRow(11).alignment = {vertical: "middle", horizontal: "left"}
        ws.getRow(11).border = {
          top: {style: "thin"},
          left: {style: "thin"},
          bottom: {style: "thin"},
          right: {style: "thin"},
        }
        if (index % 2) {
          // ws.getRow(11).fill = {type: "pattern", pattern: "gray0625"}
          ws.getRow(11).fill = {type: "pattern", pattern: "lightGray", bgColor: {argb: "FFC0D0F8"}}
        }
      })

      // set office name
      ws.getCell("C5").value = officeName

      // set month
      ws.getCell("C6").value = [
        "Januari", "Februari", "Mars", "April", "Maj", "Juni",
        "Juli", "Augusti", "September", "Oktober", "November", "December",
      ][(new Date(dateFrom)).getMonth()]

      // set date range
      ws.getCell("C8").value = `${dateFrom.substr(0, 10)} - ${dateTo.substr(0, 10)}`

      // set days header
      for (let day = 1; day <= 31; ++day) {
        ws.getRow(10).getCell(2 + day).value = (day <= daysInMonth) ? day : ""
      }

      ws.getColumn(1).width = 5
      ws.getColumn(2).width = 30

      respond(200, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
      await wb.xlsx.write(res)
      res.end()
      return
    }

  } catch(e) {
    respond(500, "application/json", JSON.stringify({
      error: e.message
    }))
    console.error(e)
    return
  }

  respond(404, "text/plain", "Not Found")
})

server.listen(PORT, HOST, () => {
  console.log(`XLSX generator is running on http://${HOST}:${PORT}...`)
})

// -----------------------------------------------------------------------------
