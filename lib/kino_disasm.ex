defmodule Kino.Disasm do
  use Kino.JS

  def new(disasm, opts \\ []) do
    Kino.JS.new(__MODULE__, to_html(disasm, opts))
  end

  def to_html(t, opts \\ []) do
    include_generated_functions = Keyword.get(opts, :generated, false)
    include_extra_info = Keyword.get(opts, :extra_info, false)

    [
      title(t),
      exports(t, include_generated_functions, include_extra_info),
      attributes(t, include_extra_info),
      compile_info(t, include_extra_info),
      functions(t, include_generated_functions)
    ]
    |> IO.iodata_to_binary()
  end

  asset "main.js" do
    """
    export function init(ctx, html) {
      ctx.importJS("https://cdn.tailwindcss.com").then(() => {
        ctx.root.innerHTML = html;
      })
    }
    """
  end

  defp title(%{mod: mod}) do
    class = "font-mono font_bold text-4xl mb-8"
    "<h1 class=\"#{class}\"><code>#{inspect(mod)}</code></h1>\n\n"
  end

  defp exports(_, _, false), do: []

  defp exports(%{exports: exports}, include_generated_functions, _include_extra_info) do
    div_class = "mb-8"
    h2_class = "font-mono font_bold text-2xl"

    exports_html =
      exports
      |> Enum.filter(fn {name, _arity, _label} ->
        include_function(name, include_generated_functions)
      end)
      |> Enum.map(fn {name, arity, _label} ->
        ["    <li><code>", name_arity(name, arity), "</code></li>\n"]
      end)

    [
      "<div class=\"#{div_class}\">\n  <h2 class=\"#{h2_class}\">exports</h2>\n  <ul>\n",
      exports_html,
      "  </ul>\n</div>\n\n"
    ]
  end

  defp attributes(_, false), do: []

  defp attributes(%{attributes: attributes}, _include_extra_info) do
    div_class = "mb-8"
    h2_class = "font-mono font_bold text-2xl"

    attributes_html =
      Enum.map(attributes, fn {key, value} ->
        ["    <li><code>", key_value(key, value), "</code></li>\n"]
      end)

    [
      "<div class=\"#{div_class}\">  <h2 class=\"#{h2_class}\">attributes</h2>\n  <ul>\n",
      attributes_html,
      "  </ul>\n</div>\n\n"
    ]
  end

  defp compile_info(_, false), do: []

  defp compile_info(%{compile_info: info}, _include_extra_info) do
    div_class = "mb-8"
    class = "font-mono font_bold text-2xl"

    info_html =
      Enum.map(info, fn {key, value} ->
        ["    <li><code>", key_value(key, value), "</code></li>\n"]
      end)

    [
      "<div class=\"#{div_class}\">\n  <h2 class=\"#{class}\">compile info</h2>\n  <ul>\n",
      info_html,
      "  </ul>\n</div>\n\n"
    ]
  end

  defp functions(%{functions: functions}, include_generated_functions) do
    div_class = "mb-8 w-max"
    class = "font-mono font_bold text-2xl"

    functions_html =
      functions
      |> Enum.filter(fn {:function, name, _arity, _label, _instructions} ->
        include_function(name, include_generated_functions)
      end)
      |> Enum.map(&function/1)

    [
      "<div class=\"#{div_class}\">\n  <h2 class=\"#{class}\">functions</h2>\n",
      functions_html,
      "</div>\n\n"
    ]
  end

  defp function({:function, name, arity, _label, instructions}) do
    div_class = "mt-4 bg-slate-100 rounded-md"
    class = "font-mono font_bold text-xl"
    title = ["    <h3 class=\"#{class}\"><code>", name_arity(name, arity), "</code></h3>\n"]

    [
      "  <div class=\"#{div_class}\">\n",
      title,
      "    <ul>\n",
      labels(instructions),
      "    </ul>\n  </div>\n\n"
    ]
  end

  defp labels(instructions) do
    instructions
    |> chunk_by_label()
    |> Enum.map(fn {label, label_ins} ->
      [
        "      <li class=\"mt-4\"><code>",
        format_instruction(label),
        "</code>",
        instructions(label_ins),
        "</li>\n"
      ]
    end)
  end

  defp chunk_by_label(instructions) do
    instructions
    |> Enum.chunk_while(
      nil,
      fn
        # first label
        {:label, _} = label, nil -> {:cont, {label, []}}
        # new label after instructions chunked under previous label
        {:label, _} = new_l, {l, ins} -> {:cont, {l, Enum.reverse(ins)}, {new_l, []}}
        # an instruction to be chunked within a label
        i, {l, ins} -> {:cont, {l, [i | ins]}}
        # a free floating instruction (at start of function before first label etc)
        i, nil -> {:cont, {i, []}, nil}
      end,
      fn {l, ins} -> {:cont, {l, Enum.reverse(ins)}, []} end
    )
  end

  defp instructions(instructions) do
    instructions
    |> Enum.map(&["        <li class=\"ml-4\"><code>", format_instruction(&1), "</code></li>\n"])
    |> then(fn
      [] -> []
      body -> ["<ul>\n", body, "      </ul>"]
    end)
  end

  defp key_value(key, value), do: "#{to_string(key)}: #{inspect(value)}"
  defp name_arity(name, arity), do: "#{to_string(name)}/#{to_string(arity)}"
  defp include_function(name, include_generated_functions)

  defp include_function(name, false)
       when name in ~w(__info__ module_info -inlined-__info__/1-)a,
       do: false

  defp include_function(_name, _), do: true

  defp format_instruction(i) do
    i
    |> fi()
    |> span()
  end

  defp span({classes, body}) when is_binary(body) do
    ["<span class=\"", Enum.intersperse(classes, " "), "\">", body, "</span>"]
  end

  defp span({classes, body_parts}) when is_list(body_parts) do
    [
      "<span class=\"",
      Enum.intersperse(classes, " "),
      "\">",
      Enum.map(body_parts, &span/1),
      "</span>"
    ]
  end

  defp span(body), do: span({[], body})

  defp fi({:label, _} = i), do: {~w[font-bold text-green-600], inspect(i)}
  defp fi({:line, _n} = i), do: {~w[text-slate-300], inspect(i)}
  defp fi({:func_info, _mod, _fun, _arity} = i), do: {~w[text-slate-400], inspect(i)}

  # registers
  defp fi({:x, _n} = i), do: {~w[text-orange-600 font-bold], inspect(i)}
  defp fi({:y, _n} = i), do: {~w[text-yellow-600 font-bold], inspect(i)}
  defp fi({:f, _n} = i), do: {~w[text-green-600 font-bold], inspect(i)}
  defp fi({:u, _n} = i), do: {~w[text-blue-600 font-bold], inspect(i)}

  # immedate values
  defp fi({type, _a} = i) when type in ~w[atom integer]a, do: {~w[text-purple-600], inspect(i)}

  # format primitives
  defp fi(t) when is_tuple(t) do
    elems =
      t
      |> Tuple.to_list()
      |> Enum.map(&fi(&1))
      |> Enum.intersperse(", ")

    ["{", elems, "}"]
  end

  defp fi(n) when is_integer(n), do: {~w[text-blue-400], to_string(n)}

  defp fi(f) when is_float(f), do: {~w[text-blue-400], to_string(f)}

  defp fi(b) when b in [true, false], do: {~w[text-blue-400], inspect(b)}

  defp fi(a) when is_atom(a) do
    a_string = a |> to_string()

    if String.starts_with?(a_string, "Elixir.") do
      {~w[text-emerald-500], String.replace_prefix(a_string, "Elixir.", "")}
    else
      [":", a_string]
    end
  end

  defp fi(m) when is_map(m) do
    elems =
      m
      |> Enum.map(fn {k, v} ->
        [fi(k), " => ", fi(v)]
      end)
      |> Enum.intersperse(", ")

    ["%{", elems, "}"]
  end

  defp fi(l) when is_list(l) do
    elems =
      l
      |> Enum.map(&fi(&1))
      |> Enum.intersperse(", ")

    ["[", elems, "]"]
  end

  defp fi(s) when is_binary(s) do
    {~w[text-lime-400], <<?", s::binary, ?">>}
  end

  defp fi(f) when is_function(f) do
    {~w[text-yellow-500], inspect(f)}
  end
end
