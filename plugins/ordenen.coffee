_ = require 'underscore'
moment = require 'moment'

module.exports = (env, callback) ->
  # *env* is the current wintersmith environment
  # *callback* should be called when the plugin has finished loading
  
  getYears = (contents) ->
    events = contents.history._.directories.map (item) -> item.index
    firstYear = (events.sort (docA, docB) -> if docA.metadata.year < docB.metadata.year then -1 else 1)[0].metadata.year
    lastYear = (new Date()).getFullYear()
    
    currentTitles = _(contents.person._.directories.map (item) -> item.index).filter (item) -> item.metadata.current
    previousTitles = _(contents.person._.directories.map (item) -> item._.directories.map (subitem) -> {
      title: subitem.index.title,
      metadata: subitem.index.metadata,
      url: item.index.url+'#'+subitem.index.metadata.current
    }).flatten()
    persons = currentTitles.concat(previousTitles)
    personHierarchy = contents['structure.json'].metadata.persons
    titleHierarchy = contents['structure.json'].metadata.titles.hierarchy.map (title) -> getTitle(title, personHierarchy)
     
    years = []
    for i in [lastYear+1...firstYear]
      years.push(getYear(i, events, persons, titleHierarchy))
    _(years).filter (year) -> year.events.length > 0 or _(year.appointments.map (appointment) -> appointment.persons).flatten().length > 0
  
  getYear = (year, events, persons, hierarchy) ->
    { 
      year: year, 
      events: ((_(events).filter (event) -> event.metadata.year is year).sort (docA, docB) -> getSortValue(docA) > getSortValue(docB)),
      appointments: (hierarchy.map (title) -> getAppointments year, title, persons)
    }
  
  getSortValue = (doc) -> getTime(doc.date, doc.metadata.year) + doc.title
  getTime = (date, year) -> if date.getTime() is 0 then moment([year, 11, 31]).toDate().getTime() else date.getTime()
  
  getAppointments = (year, title, persons) -> 
    {
      title: title.name,
      persons: _(persons).filter (person) -> person.metadata.appointed is year and person.metadata.current is title.title
    }
  
  getTitle = (title, personHierarchy) -> 
    {
      title: title,
      name: (_(personHierarchy.structure).find (insignia) -> insignia.title is title).name
    }
  
  getSources = (sources, references) ->
    sources.map (source) -> getSource source, references
  
  getSource = (source, references) -> 
    if source.match(/http/)
      sourceParts = source.split ' '
      sourceUrl = sourceParts[0]
      if references and references[sourceUrl]
        "<a href=\"\##{references[sourceUrl].index}\">#{references[sourceUrl].index}</a>"
      else
        sourceParts.shift()
        sourceName = sourceParts.join ' '
        "<a href=\"#{sourceUrl}\">#{sourceName}</a>"
    else
      source
  
  getReferences = (contents) ->
    years = getYears(contents)
    references = {}
    (_(years.map (year) -> year.events.map (event) -> event.metadata.sources).chain().flatten().uniq().value().filter (source) -> source).forEach (source, index) ->
      key = (source.split ' ')[0]
      references[key] = {
        html: getSource(source),
        index: index + 1
      }
    references
  
  getClassesForYear = (year) ->
    eventTags = _(year.events.map (event) -> if event.metadata.tags then event.metadata.tags.split(', ') else []).flatten()
    appointmentTags = if _(year.appointments.map (appointment) -> appointment.persons).flatten().length > 0 then ['ifi-ordenen'] else []
    _(eventTags.concat(appointmentTags)).uniq().map (tag) -> "year-#{tag}"
  
  # add helpers to the environment so we can use it later
  env.helpers.getClassesForYear = getClassesForYear
  env.helpers.getReferences = getReferences
  env.helpers.getSortValue = getSortValue
  env.helpers.getSources = getSources
  env.helpers.getYear = getYear
  env.helpers.getYears = getYears

  # tell plugin manager we are done
  callback()