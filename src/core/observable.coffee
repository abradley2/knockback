###
  knockback.js 0.18.6
  Copyright (c)  2011-2014 Kevin Malakoff.
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
  Source: https://github.com/kmalakoff/knockback
  Dependencies: Knockout.js, Backbone.js, and Underscore.js (or LoDash.js).
  Optional dependencies: Backbone.ModelRef.js and BackboneORM.
###

{_, ko} = kb = require './kb'
TypedValue = require './typed-value'

KEYS_PUBLISH = ['value', 'valueType', 'destroy']

# Base class for observing model attributes.
#
# @example How to create a ko.CollectionObservable using the ko.collectionObservable factory.
#   var ContactViewModel = function(model) {
#     this.name = kb.observable(model, 'name');
#     this.number = kb.observable(model, { key: 'number'});
#   };
#   var model = new Contact({ name: 'Ringo', number: '555-555-5556' });
#   var view_model = new ContactViewModel(model);
#
# @example How to create a kb.Observable with a default value.
#   var model = Backbone.Model({name: 'Bob'});
#   var name = kb.observable(model, {key:'name', default: '(none)'}); // name is Bob
#   name.setToDefault(); // name is (none)
#
# @method #model()
#   Dual-purpose getter/setter ko.computed for the observed model.
#   @return [Model|ModelRef|void] getter: the model whose attributes are being observed (can be null) OR setter: void
#   @example
#     var observable = kb.observable(new Backbone.Model({name: 'bob'}), 'name');
#     var the_model = observable.model(); // get
#     observable.model(new Backbone.Model({name: 'fred'})); // set
#
class kb.Observable

  # Used to create a new kb.Observable.
  #
  # @param [Model] model the model to observe (can be null)
  # @param [String|Array|Object] options the create options. String is a single attribute name, Array is an array of attribute names.
  # @option options [String] key the name of the attribute.
  # @option options [Function] read a function used to provide transform the attribute value before passing it to the caller. Signature: read()
  # @option options [Function] write a function used to provide transform the value before passing it to the model set function. Signature: write(value)
  # @option options [Array] args arguments to pass to the read and write functions (they can be ko.observables). Can be useful for passing arguments to a locale manager.
  # @option options [Constructor] localizer a concrete kb.LocalizedObservable constructor for localization.
  # @option options [Data|ko.observable] default the default value. Can be a value, string or ko.observable.
  # @option options [String] path the path to the value (used to create related observables from the factory).
  # @option options [kb.Store] store a store used to cache and share view models.
  # @option options [kb.Factory] factory a factory used to create view models.
  # @option options [Object] options a set of options merge into these options. Useful for extending options when deriving classes rather than merging them by hand.
  # @return [ko.observable] the constructor does not return 'this' but a ko.observable
  # @note the constructor does not return 'this' but a ko.observable
  constructor: (model, options, @_vm={}) -> return kb.ignore =>
    options or kb._throwMissing(this, 'options')

    # copy create options
    if _.isString(options) or ko.isObservable(options)
      create_options = {key: options}
    else
      create_options = kb.utils.collapseOptions(options)

    # extract options
    @key = create_options.key; delete create_options.key; @key or kb._throwMissing(this, 'key')
    not create_options.args or (@args = create_options.args; delete create_options.args)
    not create_options.read or (@read = create_options.read; delete create_options.read)
    not create_options.write or (@write = create_options.write; delete create_options.write)
    event_watcher = create_options.event_watcher
    delete create_options.event_watcher

    # set up basics
    @_value = new TypedValue(create_options)
    @_model = ko.observable()
    event_watcher = kb.EventWatcher.useOptionsOrCreate({event_watcher: event_watcher}, model or null, @, {emitter: @_model, update: (=> kb.ignore(=> @_update())), key: @key, path: create_options.path})
    @_model(event_watcher.ee)
    @_wait = ko.observable(true)

    # watch the model for changes
    observable = kb.utils.wrappedObservable @, ko.computed {
      read: =>
        return if @_wait?() or kb.wasReleased(@)
        @_update()
        return @_value.value()

      write: (new_value) => kb.ignore =>
        return if kb.wasReleased(@)
        unwrapped_new_value = kb.utils.unwrapModels(new_value) # unwrap for set (knockout may pass view models which are required for the observable but not the model)
        if @write
          @write.call(@_vm, unwrapped_new_value)
          new_value = kb.getValue(kb.peek(@_model), kb.peek(@key), @args)
        else if _model = kb.peek(@_model)
          kb.setValue(_model, kb.peek(@key), unwrapped_new_value)
        @_value.update(new_value)

      owner: @_vm
    }

    # use external model observable or create
    observable.model = @model = ko.computed {
      read: => ko.utils.unwrapObservable(@_model)
      write: (new_model) => kb.ignore => return if kb.wasReleased(@); event_watcher.emitter(new_model)
    }

    observable.__kb_is_o = true # mark as a kb.Observable
    create_options.store = kb.utils.wrappedStore(observable, create_options.store)
    create_options.path = kb.utils.pathJoin(create_options.path, @key)
    if create_options.factories and ((typeof(create_options.factories) is 'function') or create_options.factories.create)
      create_options.factory = kb.utils.wrappedFactory(observable, new kb.Factory(create_options.factory))
      create_options.factory.addPathMapping(create_options.path, create_options.factories)
    else
      create_options.factory = kb.Factory.useOptionsOrCreate(create_options, observable, create_options.path)
    delete create_options.factories
    @_wait(false); delete @_wait

    # publish public interface on the observable and return instead of this
    kb.publishMethods(observable, @, KEYS_PUBLISH)

    # wrap ourselves with a localizer
    if kb.LocalizedObservable and create_options.localizer
      observable = new create_options.localizer(observable)
      delete create_options.localizer

    # wrap ourselves with a default value
    if kb.DefaultObservable and create_options.hasOwnProperty('default')
      observable = kb.defaultObservable(observable, create_options.default)
      delete create_options.default

    return observable

  # Required clean up function to break cycles, release view models, etc.
  # Can be called directly, via kb.release(object) or as a consequence of ko.releaseNode(element).
  destroy: ->
    @__kb_released = true
    observable = kb.utils.wrappedObservable(@)
    @_value.destroy(); @_value = null
    @model.dispose(); @model = observable.model = null
    kb.utils.wrappedDestroy(@)

  # @return [kb.CollectionObservable|kb.ViewModel|ko.observable] exposes the raw value inside the kb.observable. For example, if your attribute is a Collection, it will hold a CollectionObservable.
  value: -> @_value?.peek()

  # @return [kb.TYPE_UNKNOWN|kb.TYPE_SIMPLE|kb.TYPE_ARRAY|kb.TYPE_MODEL|kb.TYPE_COLLECTION] provides the type of the wrapped value.
  valueType: -> @_value?.valueType(kb.peek(@_model), kb.peek(@key))

  # @nodoc
  _update: ->
    _model = @_model(); ko.utils.unwrapObservable(arg) for arg in args = [@key].concat(@args or [])
    kb.ignore => @_value.update(if @read then @read.apply(@_vm, args) else kb.getValue(_model, kb.peek(@key), @args))

kb.observable = (model, options, view_model) -> new kb.Observable(model, options, view_model)