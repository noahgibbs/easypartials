$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module Easypartials
  VERSION = '0.0.2'

  def self.shared_directories
    @ep_shared_directories || []
  end

  def self.shared_directories=(arglist)
    @ep_shared_directories = arglist
  end
end

module ApplicationHelper
  alias_method :method_missing_without_easy_partials, :method_missing
  alias_method :respond_to_without_easy_partials, :respond_to?

  METHOD_REGEXP = /^_(.+)$/

  def respond_to_with_easy_partials(method_name, inc_priv = false)
    return true if method_name =~ METHOD_REGEXP

    respond_to_without_easy_partials(method_name, inc_priv)
  end

  def method_missing_with_easy_partials(method_name, *args, &block)
    method_str = method_name.to_s

    if method_str =~ METHOD_REGEXP
      partial_name = method_str[METHOD_REGEXP, 1]

      self.class.class_eval <<ENDEVAL
def #{method_str}(*args, &block)
  begin
    concat_partial "#{partial_name}", *args, &block
  rescue ActionView::MissingTemplate
    last_exc = nil
    done = false
    dirs = Easypartials.shared_directories
    dirs.each do |shared|
      begin
        concat_partial shared + "/#{partial_name}", *args, &block
        done = true
      rescue ActionView::MissingTemplate => exc
        last_exc = exc
      end
      break if done
    end
    unless done
      exc = ActionView::MissingTemplate.new dirs, "#{partial_name}"
      raise exc
    end
  end
end
ENDEVAL
      self.send(method_str, *args, &block)
    else
      method_missing_without_easy_partials method_name, *args, &block
    end
  end

  alias_method :method_missing, :method_missing_with_easy_partials
  alias_method :respond_to?, :respond_to_with_easy_partials

  # Concat the given partial.
  def concat_partial(partial_name, locals = {}, &block)
    unless block.nil?
      locals.merge! :body => capture(&block)
    end

    content = render :partial => partial_name, :locals => locals
    concat content
    nil
  end
end
