var LocaleManager = function(locale_identifier, translations_by_locale) {
  this.translations_by_locale = translations_by_locale;
  this.current_locale = ko.observable(locale_identifier);

  this.get = function(string_id) {
    if (!this.translations_by_locale[this.current_locale()]) { return '(no translation)'; }
    if (!this.translations_by_locale[this.current_locale()].hasOwnProperty(string_id)) { return '(no translation)'; }
    return this.translations_by_locale[this.current_locale()][string_id];
  };

  this.getLocale = function() { return this.current_locale(); };
  this.setLocale = function(locale_identifier) {
    this.current_locale(locale_identifier);
    return this.trigger('change', this);
  };
};

_.extend(LocaleManager.prototype, Backbone.Events);