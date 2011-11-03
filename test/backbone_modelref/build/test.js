var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
$(document).ready(function() {
  module("knockback.js with Backbone.ModelRef.js");
  test("TEST DEPENDENCY MISSING", function() {
    ko.utils;
    _.VERSION;
    return Backbone.VERSION;
  });
  kb.locale_manager = new LocaleManager('en', {
    'en': {
      loading: "Loading dude"
    },
    'en-GB': {
      loading: "Loading sir"
    },
    'fr-FR': {
      loading: "Chargement"
    }
  });
  return test("Standard use case: just enough to get the picture", function() {
    var ContactViewModel, collection, current_date, model, model_ref, view_model;
    ContactViewModel = (function() {
      function ContactViewModel(model) {
        this.loading_message = new LocalizedStringLocalizer(new LocalizedString('loading'));
        this.attribute_observables = kb.observables(model, {
          name: {
            key: 'name',
            "default": this.loading_message
          },
          number: {
            key: 'number',
            write: true,
            "default": this.loading_message
          },
          date: {
            key: 'date',
            write: true,
            "default": this.loading_message,
            localizer: __bind(function(value) {
              return new LongDateLocalizer(value);
            }, this)
          }
        }, this);
      }
      ContactViewModel.prototype.destroy = function() {
        return this.attribute_observables.destroy();
      };
      return ContactViewModel;
    })();
    collection = new ContactsCollection();
    model_ref = new Backbone.ModelRef(collection, 'b4');
    view_model = new ContactViewModel(model_ref);
    kb.locale_manager.setLocale('en');
    equal(view_model.name(), 'Loading dude', "Is that what we want to convey?");
    kb.locale_manager.setLocale('en-GB');
    equal(view_model.name(), 'Loading sir', "Maybe too formal");
    kb.locale_manager.setLocale('fr-FR');
    equal(view_model.name(), 'Chargement', "Localize from day one. Good!");
    collection.add(collection.parse({
      id: 'b4',
      name: 'John',
      number: '555-555-5558',
      date: new Date(1940, 10, 9)
    }));
    model = collection.get('b4');
    equal(view_model.name(), 'John', "It is a name");
    equal(view_model.number(), '555-555-5558', "Not so interesting number");
    kb.locale_manager.setLocale('en-GB');
    equal(view_model.date(), '09 November 1940', "John's birthdate in Great Britain format");
    kb.locale_manager.setLocale('fr-FR');
    equal(view_model.date(), '09 novembre 1940', "John's birthdate in France format");
    raises((function() {
      return view_model.name('Paul');
    }), null, "Cannot write a value to a dependentObservable unless you specify a 'write' option. If you wish to read the current value, don't pass any parameters.");
    equal(model.get('name'), 'John', "Name not changed");
    equal(view_model.name(), 'John', "Name not changed");
    view_model.number('9222-222-222');
    equal(model.get('number'), '9222-222-222', "Number was changed");
    equal(view_model.number(), '9222-222-222', "Number was changed");
    kb.locale_manager.setLocale('en-GB');
    view_model.date('10 December 1963');
    current_date = model.get('date');
    equal(current_date.getFullYear(), 1963, "year is good");
    equal(current_date.getMonth(), 11, "month is good");
    equal(current_date.getDate(), 10, "day is good");
    model.set({
      name: 'Yoko',
      number: '818-818-8181'
    });
    equal(view_model.name(), 'Yoko', "Name changed");
    equal(view_model.number(), '818-818-8181', "Number was changed");
    model.set({
      date: new Date(1940, 10, 9)
    });
    kb.locale_manager.setLocale('fr-FR');
    equal(view_model.date(), '09 novembre 1940', "John's birthdate in France format");
    view_model.date('10 novembre 1940');
    current_date = model.get('date');
    equal(current_date.getFullYear(), 1940, "year is good");
    equal(current_date.getMonth(), 10, "month is good");
    equal(current_date.getDate(), 10, "day is good");
    collection.reset();
    equal(view_model.name(), 'Yoko', "Default is to retain the last value");
    view_model.attribute_observables.forceRefresh();
    kb.locale_manager.setLocale('en');
    equal(view_model.name(), 'Loading dude', "Is that what we want to convey?");
    kb.locale_manager.setLocale('en-GB');
    equal(view_model.name(), 'Loading sir', "Maybe too formal");
    kb.locale_manager.setLocale('fr-FR');
    return equal(view_model.name(), 'Chargement', "Localize from day one. Good!");
  });
});