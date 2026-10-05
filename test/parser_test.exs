defmodule CvBuilder.ParserTest do
  use ExUnit.Case, async: true

  alias CvBuilder.Parser

  test "parst een titel" do
    assert Parser.parse("# Jan Jansen") == [{:heading, 1, "Jan Jansen"}]
    assert Parser.parse("### Ervaring") == [{:heading, 3, "Ervaring"}]
  end

  test "een titel van zes hashes is nog steeds een titel" do
    assert Parser.parse("###### Diep") == [{:heading, 6, "Diep"}]
  end

  test "zeven hashes is geen titel maar tekst" do
    assert Parser.parse("####### Te diep") == [{:paragraph, "####### Te diep"}]
  end

  test "haalt de spaties na de hashes weg" do
    assert Parser.parse("#    Jan") == [{:heading, 1, "Jan"}]
  end

  test "parst een afbeelding" do
    assert Parser.parse("![foto](assets/foto.png)") == [{:image, "foto", "assets/foto.png"}]
  end

  test "een afbeelding zonder alt-tekst mag" do
    assert Parser.parse("![](assets/foto.png)") == [{:image, "", "assets/foto.png"}]
  end

  test "parst een ongeordende lijst" do
    markdown = """
    - Eerste
    - Tweede
    - Derde
    """

    assert Parser.parse(markdown) == [
             {:list, false, [{:text, "Eerste"}, {:text, "Tweede"}, {:text, "Derde"}]}
           ]
  end

  test "accepteert -, * en + als lijstteken" do
    markdown = """
    - Een
    * Twee
    + Drie
    """

    assert Parser.parse(markdown) == [
             {:list, false, [{:text, "Een"}, {:text, "Twee"}, {:text, "Drie"}]}
           ]
  end

  test "parst een genummerde lijst" do
    markdown = """
    1. Eerste
    2. Tweede
    """

    assert Parser.parse(markdown) == [{:list, true, [{:text, "Eerste"}, {:text, "Tweede"}]}]
  end

  test "een dieper genest lijstje blijft binnen de lijst" do
    markdown = """
    - Bovenste
      - Genest een
      - Genest twee
    - Weer een item
    """

    assert Parser.parse(markdown) == [
             {:list, false,
              [
                {:text, "Bovenste"},
                {:list, false, [{:text, "Genest een"}, {:text, "Genest twee"}]},
                {:text, "Weer een item"}
              ]}
           ]
  end

  test "plakt opeenvolgende regels aan elkaar tot een alinea" do
    markdown = """
    Dit is een
    alinea over drie
    regels.
    """

    assert Parser.parse(markdown) == [{:paragraph, "Dit is een alinea over drie regels."}]
  end

  test "stopt een alinea bij het volgende blok" do
    markdown = """
    Tekst
    ## Kop
    """

    assert Parser.parse(markdown) == [{:paragraph, "Tekst"}, {:heading, 2, "Kop"}]
  end

  test "stopt een alinea bij een lijst" do
    markdown = """
    Tekst
    - item
    """

    assert Parser.parse(markdown) == [{:paragraph, "Tekst"}, {:list, false, [{:text, "item"}]}]
  end

  test "een lege regel tussen twee lijstpunten maakt er geen nieuwe lijst van" do
    markdown = """
    - Eerste

    - Tweede
    """

    assert Parser.parse(markdown) == [{:list, false, [{:text, "Eerste"}, {:text, "Tweede"}]}]
  end

  test "lege regels tussen twee lijsten maken wel twee lijsten" do
    markdown = """
    - Eerste

    Nog tekst

    - Tweede
    """

    assert Parser.parse(markdown) == [
             {:list, false, [{:text, "Eerste"}]},
             {:paragraph, "Nog tekst"},
             {:list, false, [{:text, "Tweede"}]}
           ]
  end

  test "een vervolgregel hoort bij het punt erboven" do
    markdown = """
    - Begin van het punt
      en de rest ervan
    """

    assert Parser.parse(markdown) == [
             {:list, false, [{:text, "Begin van het punt en de rest ervan"}]}
           ]
  end

  test "windows-regeleindes geven geen slordige tekens" do
    markdown = "# Titel\r\n\r\n- Eerste\r\n- Tweede\r\n"

    assert Parser.parse(markdown) == [
             {:heading, 1, "Titel"},
             {:list, false, [{:text, "Eerste"}, {:text, "Tweede"}]}
           ]
  end

  test "tabs worden spaties zodat inspringing klopt" do
    markdown = "- Bovenste\n\t- Genest"

    assert Parser.parse(markdown) == [
             {:list, false, [{:text, "Bovenste"}, {:list, false, [{:text, "Genest"}]}]}
           ]
  end

  test "parst een horizontale lijn" do
    assert Parser.parse("---") == [{:rule}]
    assert Parser.parse("***") == [{:rule}]
  end

  test "een streepje met tekst is geen horizontale lijn" do
    assert Parser.parse("- item") == [{:list, false, [{:text, "item"}]}]
  end

  test "parst een citaat" do
    assert Parser.parse("> Iets gezegd") == [{:quote, "Iets gezegd"}]
  end

  test "markdown binnen een regel blijft ongesloopt" do
    assert Parser.parse("- Gebruikt **Laravel** en `C#`") == [
             {:list, false, [{:text, "Gebruikt **Laravel** en `C#`"}]}
           ]
  end

  test "leeg bestand levert niets op" do
    assert Parser.parse("") == []
    assert Parser.parse("\n\n\n") == []
  end
end
