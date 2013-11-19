class ChangeTrackingGraftElement extends GraftElement
  constructor: (properties, dirtyProperties) ->
    super properties

    @dirtyProperties = (property for property in (dirtyProperties || []) when property != 'dirtyAttributes')
    @dirtyAttributes = dirtyProperties?.dirtyAttributes || []

  # In addition to returning a copy of the element with existing properties
  # updated as requested, the element is a `ChangeTrackingGraftElement` with
  # `dirtyProperties` set correctly.
  withProperties: (properties) ->
    dirtyProperties = []
    dirtyProperties.push 'name' if properties.name?
    dirtyProperties.push 'children' if properties.children?
    if properties.attributes?
      dirtyProperties.dirtyAttributes = (attribute for attribute, _ of properties.attributes)

    copyGraftElementWithProperties = (element, updatedProperties) ->
      new ChangeTrackingGraftElement updatedProperties, dirtyProperties

    super properties

existingStructureFromElement = window.structureFromElement
window.structureFromElement = (element) ->
  existingStructureFromElement element, ChangeTrackingGraftElement
