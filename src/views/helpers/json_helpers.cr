module Ktistec::ViewHelper
  # Renders an ActivityPub collection as JSON-LD.
  #
  macro activity_pub_collection(collection, &block)
    %path = env.request.path
    %query = env.params.query
    %cursor = {{ collection }}.cursor_start
    if %cursor
      # cursor-based pagination
      content_io << %Q({)
      content_io << %Q("@context":"https://www.w3.org/ns/activitystreams",)
      %unpaged = !%query["max_id"]? && !%query["min_id"]?
      if %unpaged
        content_io << %Q("type":"OrderedCollection",)
        content_io << %Q("id":"#{host}#{%path}",)
        content_io << %Q("first":{)
        content_io << %Q("type":"OrderedCollectionPage",)
        %qs = %query.to_s.presence
        content_io << %Q("id":"#{host}#{%path}#{%qs ? "?#{%qs}" : ""}",)
      else
        content_io << %Q("type":"OrderedCollectionPage",)
        content_io << %Q("id":"#{host}#{%path}?#{%query}",)
        %temp = %query.dup
        %temp.delete_all("max_id")
        %temp.delete_all("min_id")
        %temp["min_id"] = {{ collection }}.cursor_start.to_s
        content_io << %Q("prev":"#{host}#{%path}?#{%temp}",)
      end
      if {{ collection }}.more?
        %temp = %query.dup
        %temp.delete_all("max_id")
        %temp.delete_all("min_id")
        %temp["max_id"] = {{ collection }}.cursor_end.to_s
        content_io << %Q("next":"#{host}#{%path}?#{%temp}",)
      end
      content_io << %Q("orderedItems":[)
      {% if block %}
        {{ collection }}.each_with_index do |{{ block.args.join(",").id }}|
          {{ block.body }}
        end
      {% end %}
      content_io << %Q(])
      if %unpaged
        content_io << %Q(})
      end
      content_io << %Q(})
    else
      # page/offset-based pagination
      %page = %query["page"]?.try(&.to_i) || 1
      %page = %page > 0 ? %page : 1
      content_io << %Q({)
      content_io << %Q("@context":"https://www.w3.org/ns/activitystreams",)
      %unpaged = !%query["page"]?
      if %unpaged
        content_io << %Q("type":"OrderedCollection",)
        content_io << %Q("id":"#{host}#{%path}",)
        content_io << %Q("first":{)
        content_io << %Q("type":"OrderedCollectionPage",)
        %query["page"] = "1"
        content_io << %Q("id":"#{host}#{%path}?#{%query}",)
      else
        content_io << %Q("type":"OrderedCollectionPage",)
        content_io << %Q("id":"#{host}#{%path}?#{%query}",)
        if %page > 1
          %query["page"] = (%page - 1).to_s
          content_io << %Q("prev":"#{host}#{%path}?#{%query}",)
        end
      end
      if {{ collection }}.more?
        %query["page"] = (%page + 1).to_s
        content_io << %Q("next":"#{host}#{%path}?#{%query}",)
      end
      content_io << %Q("orderedItems":[)
      {% if block %}
        {{ collection }}.each_with_index do |{{ block.args.join(",").id }}|
          {{ block.body }}
        end
      {% end %}
      content_io << %Q(])
      if %unpaged
        content_io << %Q(})
      end
      content_io << %Q(})
    end
  end

  macro error_block(model, comma = true)
    if (%errors = {{ model }}.errors.presence)
      %comma = {{ comma }} ? "," : ""
      %errors = %errors.transform_keys(&.split(".").last).to_json
      %Q("errors":#{%errors}#{%comma})
    else
      ""
    end
  end

  macro field_pair(model, field, comma = true)
    %comma = {{ comma }} ? "," : ""
    %value = {{ model }}.{{ field.id }}.try(&.inspect) || "null"
    %Q("{{ field.id }}":#{%value}#{%comma})
  end
end
