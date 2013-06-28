local widget = require("widget")
local EventEmitter = require("lua-events").EventEmitter
local timeago = require("lua-timeago")

timeago.setlanguage("nederlands")
timeago.setstyle("short")

local items = {}

local margin = {
  width = 20,
  height = 10,
  spacing = 0
}
local fontsize = {
  small = 12,
  large = 15
}
local font = "Roboto-Light"

local function rowrender (event)
  local row = event.row
  local item = items[row.id]
  item.index = row.index -- needed as the prameter for TableViewWidget:deleteRow()
  local report = item.report

  local whenago = timeago.parse(report.when)
  local whentext = display.newText(row, whenago, 0, 0, font, fontsize.small)
  whentext.x = margin.width + row.x - row.contentWidth / 2 + whentext.contentWidth / 2
  whentext.y = margin.height + whentext.contentHeight / 2
  whentext:setTextColor(150, 150, 150)

  local whotext = display.newText(row, report.who, 0, 0, font, fontsize.small)
  whotext.x = row.x + row.contentWidth / 2 - whotext.contentWidth / 2 - margin.width
  whotext.y = whentext.y
  whotext:setTextColor(150, 150, 150)

  local textwidth = row.contentWidth - 2 * margin.width
  local textheight = row.contentHeight - whentext.contentHeight - 2 * margin.height - margin.spacing
  local whattext = display.newText(row, report.what, 0, 0, textwidth, textheight, font, fontsize.large)
  whattext.x = margin.width + row.x - row.contentWidth / 2 + whattext.contentWidth / 2
  whattext.y = margin.spacing + whentext.y + whentext.contentHeight / 2 + whattext.contentHeight / 2
  whattext:setTextColor(0, 0, 0)
end

local slide = {
  left = 0,
  right = display.viewableContentWidth * .8,
  position = "left",
  startthreshold = 10,
  swipethreshold = 75
}

local content, tableview = EventEmitter:new()

function content:init (top)
  tableview = widget.newTableView({
    left = slide[slide.position],
    top = top,
    width = display.viewableContentWidth,
    height = display.viewableContentHeight - top,
    onRowRender = rowrender
  })

  -- FIXME; can break on any new widget version,
  -- but for now probably a better solution than keeping a fork of the widget library.
  -- The problem is that the TableView widget uses up all touch hook points for its
  -- implementation of table scrolling and row selecting & swiping, and doesn't
  -- provide any possibility for touch extension through its API.
  -- The tableview[2] part is the dirty hack here.
  local view = tableview[2]
  local widgettouch = view.touch
  function view:touch (event)

    -- desired behaviour:
    -- * start scrolling or sliding only when moved more than a certain threshold
    -- * no sliding while scrolling; no scrolling while sliding
    -- * only scrolling if in left position
    -- * when sliding, snap back to current position if not slided further than a certain threshold
    -- * when in right position, sliding to the left will do the nice sliding; any other movement,
    --   including tapping, will snap it back to the left position

    local function direction ()
      if event.x > event.xStart then return "right"
      else return "left" end
    end

    local distance = {}
    function distance._d (a, b) return math.abs(a - b) end
    function distance:x () return self._d(event.x, event.xStart) end
    function distance:y () return self._d(event.y, event.yStart) end

    if "began" == event.phase then
      slide.sliding, slide.scrolling = false, false
      widgettouch(view, event)

    elseif "moved" == event.phase then
      if not slide.sliding and not slide.scrolling
      and "left" == slide.position
      and distance:y() > slide.startthreshold then
        slide.scrolling = true
      end
      if not slide.scrolling and not slide.sliding
      and direction() ~= slide.position
      and distance:x() > slide.startthreshold then
        slide.sliding = true
      end

      if slide.scrolling then
        widgettouch(view, event)
      elseif slide.sliding
      and tableview.x >= slide.left and tableview.x <= slide.right then
        tableview.x = tableview.x + (event.x - slide.prevx)
      end

    elseif "ended" == event.phase or "canceled" == event.phase then
      if slide.sliding then
        if distance:x() > slide.swipethreshold then
          content:slide(direction())
        else
          content:slide(slide.position)
        end
      elseif "right" == slide.position then
        content:slide("left")
      end
      slide.sliding, slide.scrolling = false, false
      widgettouch(view, event)
    end

    slide.prevx = event.x
    return true
  end
end

function content:slide (leftorright)
  self:emit("slide", leftorright)
  if tableview.x == slide[leftorright] then return end
  slide.position = leftorright
  transition.to(tableview, {
    time = 400,
    transition = easing.outExpo,
    x = slide[leftorright]
  })
end

function content:add (id, report, action)
  if items[id] then return end
  items[id] = {report = report, action = action}
  for _,match in ipairs({"\n", "\r", "\t", "  ", "  "}) do
    report.what = string.gsub(report.what, match, " ")
  end
  local availablewidth = tableview.contentWidth - 2 * margin.width
  local line = display.newText(report.what, 0, 0, font, fontsize.large)
  local height = line.contentHeight
  if line.contentWidth > availablewidth then
    height = line.contentHeight * math.ceil(line.contentWidth / (availablewidth * .95) )
  end
  display.remove(line)
  line = display.newText("", 0, 0, font, fontsize.small)
  height = height + line.contentHeight
  display.remove(line)
  height = height + 2 * margin.height + margin.spacing
  tableview:insertRow({
    id = id,
    rowHeight = height
  })
end

function content:empty ()
  tableview:deleteAllRows()
  for k in pairs(items) do
    items[k] = nil
  end
end

return content
