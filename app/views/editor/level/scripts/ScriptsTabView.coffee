CocoView = require 'views/kinds/CocoView'
template = require 'templates/editor/level/scripts_tab'
Level = require 'models/Level'
Surface = require 'lib/surface/Surface'
nodes = require './../treema_nodes'

module.exports = class ScriptsTabView extends CocoView
  id: 'editor-level-scripts-tab-view'
  template: template
  className: 'tab-pane'

  subscriptions:
    'level-loaded': 'onLevelLoaded'

  constructor: (options) ->
    super options
    @world = options.world
    @files = options.files

  onLoaded: ->
  onLevelLoaded: (e) ->
    @level = e.level
    @dimensions = @level.dimensions()
    scripts = $.extend(true, [], @level.get('scripts') ? [])
    treemaOptions =
      schema: Level.schema.properties.scripts
      data: scripts
      callbacks:
        change: @onScriptsChanged
        select: @onScriptSelected
        addChild: @onNewScriptAdded
        removeChild: @onScriptDeleted
      nodeClasses:
        array: ScriptsNode
        object: ScriptNode
      view: @
    @scriptsTreema = @$el.find('#scripts-treema').treema treemaOptions
    @scriptsTreema.build()
    if @scriptsTreema.childrenTreemas[0]?
      @scriptsTreema.childrenTreemas[0].select()
      @scriptsTreema.childrenTreemas[0].broadcastChanges() # can get rid of this after refactoring treema

  onScriptsChanged: (e) =>
    @level.set 'scripts', @scriptsTreema.data

  onScriptSelected: (e, selected) =>
    selected = if selected.length > 1 then selected[0].getLastSelectedTreema() else selected[0]
    unless selected
      @$el.find('#script-treema').replaceWith($('<div id="script-treema"></div>'))
      @selectedScriptPath = null
      return

    thangIDs = @getThangIDs()
    treemaOptions =
      world: @world
      filePath: "db/level/#{@level.get('original')}"
      files: @files
      view: @
      schema: Level.schema.properties.scripts.items
      data: selected.data
      thangIDs: thangIDs
      dimensions: @dimensions
      supermodel: @supermodel
      readOnly: me.get('anonymous')
      callbacks:
        change: @onScriptChanged
      nodeClasses:
        object: PropertiesNode
        'event-value-chain': EventPropsNode
        'event-prereqs': EventPrereqsNode
        'event-prereq': EventPrereqNode
        'event-channel': ChannelNode
        'thang': nodes.ThangNode
        'milliseconds': nodes.MillisecondsNode
        'seconds': nodes.SecondsNode
        'point2d': nodes.WorldPointNode
        'viewport': nodes.WorldViewportNode
        'bounds': nodes.WorldBoundsNode

    newPath = selected.getPath()
    return if newPath is @selectedScriptPath
    @scriptTreema = @$el.find('#script-treema').treema treemaOptions
    @scriptTreema.build()
    @scriptTreema.childrenTreemas?.noteChain?.open()
    @selectedScriptPath = newPath

  getThangIDs: ->
    (t.id for t in @level.get('thangs') when t.id isnt 'Interface')

  onNewScriptAdded: (scriptNode) =>
    return unless scriptNode
    if scriptNode.data.id is undefined
      scriptNode.disableTracking()
      scriptNode.set '/id', 'Script-' + @scriptsTreema.data.length
      scriptNode.enableTracking()

  onScriptDeleted: =>
    for key, treema of @scriptsTreema.childrenTreemas
      key = parseInt(key)
      treema.disableTracking()
      if /Script-[0-9]*/.test treema.data.id
        existingKey = parseInt(treema.data.id.substr(7))
        if existingKey isnt key+1
          treema.set 'id', 'Script-' + (key+1)
      treema.enableTracking()

  onScriptChanged: =>
    @scriptsTreema.set(@selectedScriptPath, @scriptTreema.data)

  undo: ->
    if @scriptTreema.canUndo() then @scriptTreema.undo() else @scriptsTreema.undo()

  redo: ->
    if @scriptTreema.canRedo() then @scriptTreema.redo() else @scriptsTreema.redo()

  showUndoDescription: ->
    if @scriptTreema.canUndo()
      undoDescription = @scriptTreema.getUndoDescription()
    else 
      undoDescription = @scriptsTreema.getUndoDescription()
    titleText = $('#undo-button').attr('title', 'Undo ' + undoDescription + ' (Ctrl+Z)')

  showRedoDescription: ->
    if @scriptTreema.canRedo()
      redoDescription = @scriptTreema.getRedoDescription()
    else 
      redoDescription = @scriptsTreema.getRedoDescription()
    titleText = $('#redo-button').attr('title', 'Redo ' + redoDescription + ' (Ctrl+Shift+Z)')

class ScriptsNode extends TreemaArrayNode
  addNewChild: ->
    newTreema = super()
    if @callbacks.addChild
      @callbacks.addChild newTreema
    newTreema

  getUndoDescription: ->
    return '' unless @canUndo()
    trackedActions = @getTrackedActions()
    currentStateIndex = @getCurrentStateIndex()
    return @getTrackedActionDescription( trackedActions[currentStateIndex - 1] )

  getRedoDescription: ->
    return '' unless @canRedo()
    trackedActions = @getTrackedActions()
    currentStateIndex = @getCurrentStateIndex()
    return @getTrackedActionDescription trackedActions[currentStateIndex]

  getTrackedActionDescription: (trackedAction) ->
    switch trackedAction.action
      when 'insert'
        trackedActionDescription = 'Add New Script'

      when 'delete'
        trackedActionDescription = 'Delete Script'

      when 'edit'
        path = trackedAction.path.split '/'
        trackedActionDescription = 'Edit Script'

      else
        trackedActionDescription = ''
    trackedActionDescription

class ScriptNode extends TreemaObjectNode
  valueClass: 'treema-script'
  collection: false
  buildValueForDisplay: (valEl) ->
    val = @data.id or @data.channel
    s = "#{val}"
    @buildValueForDisplaySimply valEl, s

  onTabPressed: (e) ->
    @tabToCurrentScript()
    e.preventDefault()

  onDeletePressed: (e) ->
    returnVal = super(e)
    if @callbacks.removeChild
      @callbacks.removeChild() 
    returnVal

  onRightArrowPressed: ->
    @tabToCurrentScript()

  tabToCurrentScript: ->
    @settings.view.scriptTreema?.keepFocus()
    window.v = @settings.view
    firstRow = @settings.view.scriptTreema?.$el.find('.treema-node:visible').data('instance')
    return unless firstRow?
    firstRow.select()

class PropertiesNode extends TreemaObjectNode
  getUndoDescription: ->
    return '' unless @canUndo()
    trackedActions = @getTrackedActions()
    currentStateIndex = @getCurrentStateIndex()
    return @getTrackedActionDescription( trackedActions[currentStateIndex - 1] )

  getRedoDescription: ->
    return '' unless @canRedo()
    trackedActions = @getTrackedActions()
    currentStateIndex = @getCurrentStateIndex()
    return @getTrackedActionDescription trackedActions[currentStateIndex]

  getTrackedActionDescription: (trackedAction) ->
    switch trackedAction.action
      when 'insert'
        trackedActionDescription = 'Add New Script Property'

      when 'delete'
        trackedActionDescription = 'Delete Script Property'

      when 'edit'
        path = trackedAction.path.split '/'
        trackedActionDescription = 'Edit Script Property'

      else
        trackedActionDescription = ''
    trackedActionDescription

class EventPropsNode extends TreemaNode.nodeMap.string
  valueClass: 'treema-event-props'

  arrayToString: -> (@data or []).join('.')

  buildValueForDisplay: (valEl) ->
    joined = @arrayToString()
    joined = '(unset)' if not joined.length
    @buildValueForDisplaySimply valEl, joined

  buildValueForEditing: (valEl) -> 
    super(valEl)
    channel = @getRoot().data.channel
    channelSchema = Backbone.Mediator.channelSchemas[channel]
    autocompleteValues = []
    autocompleteValues.push key for key, val of channelSchema?.properties
    valEl.find('input').autocomplete(source: autocompleteValues, minLength: 0, delay: 0, autoFocus: true).autocomplete('search')
    valEl

  saveChanges: (valEl) ->
    @data = (s for s in $('input', valEl).val().split('.') when s.length)

class EventPrereqsNode extends TreemaNode.nodeMap.array
  open: (depth=2) ->
    super(depth)

  addNewChild: ->
    newTreema = super(arguments)
    return unless newTreema?
    newTreema.open()
    newTreema.childrenTreemas.eventProps?.edit()

class EventPrereqNode extends TreemaNode.nodeMap.object
  buildValueForDisplay: (valEl) ->
    eventProp = (@data.eventProps or []).join('.')
    eventProp = '(unset)' unless eventProp.length
    statements = []
    for key, value of @data
      continue if key is 'eventProps'
      comparison = @schema.properties[key].title
      value = value.toString()
      statements.push("#{comparison} #{value}")
    statements = statements.join(', ')
    s = "#{eventProp} #{statements}"
    @buildValueForDisplaySimply valEl, s

class ChannelNode extends TreemaNode.nodeMap.string
  buildValueForEditing: (valEl) ->
    super(valEl)
    autocompleteValues = ({label: val?.title or key, value: key} for key, val of Backbone.Mediator.channelSchemas)
    valEl.find('input').autocomplete(source: autocompleteValues, minLength: 0, delay: 0, autoFocus: true)
    valEl
