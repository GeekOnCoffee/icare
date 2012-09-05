module ApplicationHelper

  def title(page_title)
    content_for(:title) { page_title.to_s }
  end

  def yield_or_default(section, default = "")
    content_for?(section) ? content_for(section) + (" | #{APPNAME}" unless (logged_in? || content_for(section) == APPNAME)) : default
  end

  def twitterized_type(type)
    case type
      when :alert
        "warning"
      when :error
        "error"
      when :notice
        "info"
      when :success
        "success"
      else
        type.to_s
    end
  end

  def transparent_gif_image_data
    "data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="
  end

  def check_root
    params[:controller].eql?('pages') and params[:action].eql?('home')
  end

  def bootstrap_form_for(object, options = {}, &block)
    options[:builder] = BootstrapFormBuilder
    form_for(object, options, &block)
  end

  def options_for_array_collection(model, attr_name, *args)
    options_for_select("#{model}::#{attr_name.to_s.upcase}".safe_constantize.map { |e| [ model.human_attribute_name("#{attr_name}_#{e}"), e] }, *args)
  end

  def collection_count(collection)
    "(#{collection.size})" if collection.any?
  end

  def share_on_timeline_available
    Resque.workers.any?
  rescue
    false
  end
end
