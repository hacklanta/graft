class ChangeTrackingGraftElement extends GraftElement
  constructor: (@domElement, properties, dirtyProperties) ->
    super @domElement, properties

    @dirtyProperties = (property for property in (dirtyProperties || []) when property != 'dirtyAttributes')
    @dirtyAttributes = dirtyProperties?.dirtyAttributes || []

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

    super properties, (element, updatedProperties) ->
      new ChangeTrackingGraftElement element.domElement, updatedProperties, dirtyProperties

existingStructureFromElement = window.structureFromElement
window.structureFromElement = (element) ->
  existingStructureFromElement element, ChangeTrackingGraftElement
