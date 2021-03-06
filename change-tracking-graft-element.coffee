window.graft = graft = {}
graft.event = (name, data) ->
  event = $.Event(name)
  event[prop] = value for prop, value of data

  $(document).trigger event

class ChangeTrackingGraftElement extends GraftElement
  constructor: (@domElement, properties, dirtyProperties) ->
    super @domElement, properties

    @dirtyProperties = (property for property in (dirtyProperties || []) when property != 'dirtyAttributes')
    @dirtyAttributes = dirtyProperties?.dirtyAttributes || []

  isDirty: ->
    @dirtyProperties.length || @dirtyAttributes.length

  # In addition to returning a copy of the element with existing properties
  # updated as requested, the element is a `ChangeTrackingGraftElement` with
  # `dirtyProperties` set correctly.
  withProperties: (properties) ->
    dirtyProperties = @dirtyProperties
    dirtyProperties.push 'name' if properties.name?
    dirtyProperties.push 'children' if properties.children?
    if properties.attributes?
      dirtyAttributes = (attribute for attribute, _ of properties.attributes)
      if dirtyProperties.dirtyAttributes?
        dirtyProperties.dirtyAttributes = dirtyProperties.dirtyAttributes.concat(dirtyAttributes)
      else
        dirtyProperties.dirtyAttributes = dirtyAttributes

    updatedCopy =
      super properties, (element, updatedProperties) ->
          new ChangeTrackingGraftElement element.domElement, updatedProperties, dirtyProperties

    graft.event 'element-changed', before: this, after: updatedCopy

    updatedCopy

existingStructureFromElement = window.structureFromElement
window.structureFromElement = (domElement) ->
  existingStructureFromElement domElement, ChangeTrackingGraftElement
