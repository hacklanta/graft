# Algorithm:
#  - graft functions produce a set of transformations to be applied to
#    the tree
#  - they receive a simplified version of the DOM tree that includes only
#    structural (parent/children) and content (text/attributes) data.
#  - out-of-band modifications are ignored
#  - on change, the changes are applied to the actual DOM either by wholesale
#    object replacement, or by in-place updates (depending on data)
#  - changes are applied hierarchically, bottom to top
#  - event handlers have to be specified as part of the graft and need to be
#    attached after any other updates
#
# Concerns:
#  - there is an up-front cost to setting the DOM structure to the lightweight
#    graft representation
#  - need to make the decision on replacement vs update quickly
#  - events attached independently of the graft within the grafted structure
#    are liable to be lost on tree update

# Tree element structure:
#  parent: possibly-null
#  children: array
#  text: all immediate child nodes concatenated; updates are prefixed as a text node!
#  attributes: JS object, string -> string
# To update:
#  .withProperties(property: value, property: value)
#  .withAttributes(attribute: value, attribute: value)
# Both of these return copies.

fold = (list, accumulator, folder) ->
  for item in list
    accumulator = folder(accumulator, item)
    accumulator

  accumulator

flatten = (list) ->
  fold list, [], (newList, item) ->
    if isArray(item)
      newList = newList.concat item
    else
      newList.push item

    newList

inArray = (list, toFind) ->
  fold list, false, (found, item) ->
    found || item == toFind

isArray = (object) ->
  Object.prototype.toString.call(object) == '[object Array]'

asArray = (object) ->
  if isArray object
    object
  else
    [object]

# Return a wrapper object for the array that adds a `map` function to it. Note
# that this only works if the function expecting this object only expects a
# map function. The original array is available in the `array` property.
#
# Also note that the map function returns a similarly-wrapped object.
asMappableArray = (array) ->
  map: (fn) -> asMapableArray(fn(item) for item in @array)
  array: array

class GraftElement
  constructor: (properties) ->
    properties.attributes ||= []
    this[property] = value for property, value of properties

    @classes = @attributes['class']?.split(/\s+/) || []

  text: ->
    fold @children, '', (textSoFar, child) ->
      if typeof child == 'string'
        textSoFar + child
      else
        textSoFar

  # - Use Object.create for diff-cloning?
  # - Tag modified attributes
  withProperties: (properties) ->
    new GraftElement
      name: properties.name || @name
      children: properties.children || @children
      text: properties.text || @text
      attributes: properties.attributes || @attributes

  withAttribute: (attribute, value) ->
    newAttributes = JSON.parse(JSON.stringify(@attributes))
    newAttributes[attribute] = value

    @withProperties attributes: newAttributes

window.structureFromElement = (element) ->
  structure = null

  children =
    fold element.childNodes, [], (childrenSoFar, child) ->
      if child.nodeType == Node.TEXT_NODE
        childrenSoFar.push child.textContent || child.innerText
      else if child.nodeType == Node.ELEMENT_NODE
        childrenSoFar.push structureFromElement(child)

      childrenSoFar

  structure =
    new GraftElement
      name: element.nodeName.toLowerCase()
      children: children
      attributes: fold element.attributes, {}, (attributesSoFar, attribute) ->
        attributesSoFar[attribute.name] = attribute.value
        attributesSoFar

window.graft = (generator) ->
  transformationFromGenerator generator

transformationFromGenerator = (generator) ->
  switch typeof generator
    when 'string' or 'number'
      graftContentGenerator generator
    when 'function'
      graftFunctionGenerator generator
    when 'object'
      if generator.map?
        graftArrayGenerators generator
      else if isArray(generator)
        graftArrayGenerators asMappableArray(generator)
      else
        graftObjectGenerator generator

graftContentGenerator = (generator) ->
  (element) -> generator

graftFunctionGenerator = (generator) ->
  (element) -> generator(element)

graftArrayGenerators = (generators) ->
  transformations = generators.map(transformationFromGenerator)

  (element) ->
    transformations.map (transformation) ->
      transformation element

graftObjectGenerator = (generator) ->
  transformations =
    for selectorString, generators of generator
      graftSelector selectorString, generators

  (element) ->
    fold transformations, element, (updatedElement, transform) ->
      transform updatedElement

graftSelector = (selectorString, generator) ->
  transform = graft generator
  updater = updaterFor selectorString, transform

  (element) ->
    updater element

updaterFor = (selectorString, transform) ->
  [selector, update] = selectorAndUpdateFunctionsFrom selectorString

  updater =
    (child) ->
      if typeof child == 'string'
        child
      else
        # First apply to children, then apply to this level.
        updatedChild =
          child.withProperties
            children: flatten(
              for element in child.children
                updater(element)
            )

        if selector(updatedChild)
          update updatedChild, transform(updatedChild)
        else
          updatedChild

selectorAndUpdateFunctionsFrom = (selectorString) ->
  match = null
  if match = /(.*) \[([^\]]+)\]$/.exec(selectorString)
    [strippedSelectorString, attribute] = match[1..]
    
    [
      selectorFrom(strippedSelectorString),
      if attribute.charAt(attribute.length - 1) == '+'
        appendingAttributeUpdaterFor attribute.substring(0, attribute.length - 1)
      else
        replacingAttributeUpdaterFor attribute
    ]
  else if match = /(.*) \*$/.exec(selectorString)
    [strippedSelectorString, _] = match[1..]

    [
      selectorFrom(strippedSelectorString),
      childUpdater
    ]
  else
    [
      selectorFrom(selectorString),
      replaceUpdater
    ]

selectorFrom = (selectorString) ->
  matchers = matchersFrom selectorString

  (element) ->
    fold matchers, true, (matching, matcher) ->
      matching && matcher(element)

appendingAttributeUpdaterFor = (attribute) ->
  (element, value) ->
    attributeValue =
      if element.attributes[attribute]
        element.attributes[attribute] + ' ' + value
      else
        value

    element.withAttribute attribute, attributeValue

replacingAttributeUpdaterFor = (attribute) ->
  (element, value) ->
    element.withAttribute attribute, value

childUpdater = (element, value) ->
  element.withProperties children: flatten(asArray(value))

replaceUpdater = (element, value) ->
  if isArray(value)
    flatten(value)
  else
    value

matchersFrom = (selectorString) ->
  # start and end are always empty strings because they are before and
  # after the place where the string was split by this regex, respectively
  [_, selectorParts..., _] = selectorString.split /([#.]?[^ #.]+)/

  # We have to deal with these in twos
  fold selectorParts, [], (matchersSoFar, selectorPart) ->
    matchersSoFar.push(
      switch selectorPart.charAt(0)
        when '#'
          idSelectorFor(selectorPart.substring(1))
        when '.'
          classSelectorFor(selectorPart.substring(1))
        else
          nodeNameSelectorFor(selectorPart)
    )

    matchersSoFar

idSelectorFor = (id) ->
  (element) -> element.attributes.id == id

classSelectorFor = (className) ->
  (element) -> inArray element.classes, className

nodeNameSelectorFor = (name) ->
  (element) -> element.name == name
