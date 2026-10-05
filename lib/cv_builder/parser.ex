defmodule CvBuilder.Parser do
  @moduledoc """
  Zet een markdown-bestand om in een lijst met elementen.

  De parser kent de volgende blokken:

    * `{:heading, niveau, tekst}` voor `#` t/m `######`
    * `{:paragraph, tekst}` voor alinea's, regels worden aan elkaar
      vastgeplakt tot één alinea
    * `{:list, ordered?, items}` voor `-`, `*`, `+` en `1.`, met geneste
      lijstjes
    * `{:image, alt, pad}` voor `![alt](pad)`
    * `{:quote, tekst}` voor `>`
    * `{:rule}` voor `---`

  De parser escapt nog niets; dat doet `CvBuilder.Inline` bij het renderen.
  Zo blijft het onderscheid tussen de parser en de renderer netjes.
  """

  @heading ~r/^(\#{1,6})\s+(.*)$/
  @rule ~r/^\s*(?:([-*_])\s*)\1\1+\s*$/
  @bullet ~r/^(\s*)([-*+]|\d+[.)])\s+(.*)$/
  @quote ~r/^\s*>\s?(.*)$/
  @image ~r/^!\[([^\]]*)\]\(\s*([^)\s]+)(?:\s+"[^"]*")?\s*\)$/

  @doc """
  Zet `markdown` om in een lijst elementen.
  """
  def parse(markdown) do
    markdown
    |> normalize()
    |> String.split("\n")
    |> parse_lines([])
  end

  # Windows-regeleindes en tabs zouden anders als losse tekens blijven plakken.
  defp normalize(markdown) do
    markdown
    |> String.replace(~r/\r\n?/, "\n")
    |> String.replace("\t", "  ")
  end

  defp parse_lines([], acc), do: Enum.reverse(acc)
  defp parse_lines(["" | rest], acc), do: parse_lines(rest, acc)

  defp parse_lines([line | rest] = lines, acc) do
    cond do
      rule?(line) ->
        parse_lines(rest, [{:rule} | acc])

      heading?(line) ->
        {level, text} = parse_heading(line)
        parse_lines(rest, [{:heading, level, text} | acc])

      quote?(line) ->
        parse_lines(rest, [{:quote, parse_quote(line)} | acc])

      image?(line) ->
        parse_lines(rest, [parse_image(line) | acc])

      bullet?(line) ->
        ordered? = ordered?(line)
        {items, rest} = take_items(lines, [], indent_of(line))
        parse_lines(rest, [{:list, ordered?, items} | acc])

      true ->
        {text, rest} = take_paragraph(lines, [])
        parse_lines(rest, [{:paragraph, text} | acc])
    end
  end

  defp rule?(line), do: Regex.match?(@rule, line)
  defp bullet?(line), do: Regex.match?(@bullet, line)
  defp heading?(line), do: parse_heading(line) != nil
  defp quote?(line), do: parse_quote(line) != nil
  defp image?(line), do: parse_image(line) != nil

  defp ordered?(line) do
    case Regex.run(@bullet, line) do
      [_all, _indent, marker, _content] -> Regex.match?(~r/^\d/, marker)
      _ -> false
    end
  end

  defp indent_of(line) do
    case Regex.run(~r/^(\s*)/, line) do
      [_all, indent] -> String.length(indent)
      _ -> 0
    end
  end

  defp parse_heading(line) do
    case Regex.run(@heading, line) do
      [_all, hashes, text] ->
        {String.length(hashes), String.trim(text)}

      _ ->
        nil
    end
  end

  defp parse_quote(line) do
    case Regex.run(@quote, line) do
      [_all, text] -> String.trim(text)
      _ -> nil
    end
  end

  defp parse_image(line) do
    case Regex.run(@image, line) do
      [_all, alt, path] -> {:image, String.trim(alt), String.trim(path)}
      _ -> nil
    end
  end

  # Een alinea loopt door tot de volgende lege regel of het volgende blok.
  defp take_paragraph([], acc), do: {Enum.join(Enum.reverse(acc), " "), []}

  defp take_paragraph([line | rest] = lines, acc) do
    if String.trim(line) == "" or block_start?(line) do
      {Enum.join(Enum.reverse(acc), " "), lines}
    else
      take_paragraph(rest, [String.trim(line) | acc])
    end
  end

  defp block_start?(line) do
    rule?(line) or bullet?(line) or heading?(line) or quote?(line) or image?(line)
  end

  # Verzamelt alle punten van een lijst. `base` is de inspringing van het
  # eerste punt, daarmee bepalen we wanneer een genest lijstje begint.
  defp take_items([], acc, _base), do: {Enum.reverse(acc), []}

  defp take_items([line | rest], acc, base) do
    cond do
      String.trim(line) == "" ->
        if list_continues?(rest, base) do
          take_items(rest, acc, base)
        else
          {Enum.reverse(acc), [line | rest]}
        end

      match = Regex.run(@bullet, line) ->
        [_all, indent, _marker, content] = match
        indent = String.length(indent)

        cond do
          indent == base ->
            take_items(rest, [{:text, String.trim(content)} | acc], base)

          indent > base ->
            # Het punt waarop dit lijstje begint is het eerste punt erin.
            {sub, rest} = take_items(rest, [{:text, String.trim(content)}], indent)
            take_items(rest, [{:list, ordered?(line), sub} | acc], base)

          true ->
            {Enum.reverse(acc), [line | rest]}
        end

      indent_of(line) > base ->
        # Vervolgregel van het vorige punt, bv. een regel die is omgebroken.
        take_items(rest, append_to_last(acc, String.trim(line)), base)

      true ->
        {Enum.reverse(acc), [line | rest]}
    end
  end

  defp append_to_last([{:text, text} | rest], extra) do
    [{:text, text <> " " <> extra} | rest]
  end

  defp append_to_last(acc, _extra), do: acc

  # Kijkt of er na eventuele lege regels nog een punt van dezelfde lijst volgt,
  # zodat een lijst met tussentijds een lege regepoot één lijst blijft.
  defp list_continues?(lines, base) do
    lines
    |> Enum.drop_while(&(String.trim(&1) == ""))
    |> case do
      [] ->
        false

      [next | _] ->
        case Regex.run(@bullet, next) do
          [_all, indent, _marker, _content] -> String.length(indent) >= base
          _ -> false
        end
    end
  end
end
