defmodule CvBuilder.ConfigTest do
  use ExUnit.Case, async: true

  alias CvBuilder.Config

  test "zonder bestand krijg je de standaardwaarden" do
    config = Config.load("bestaat-niet.json")

    assert config.accent == "#1d4ed8"
    assert config.email == nil
    assert config.photo == nil
  end

  test "leest de instellingen uit json" do
    config =
      Config.from_map(%{
        "accent" => "#0f766e",
        "email" => "j@example.nl",
        "max_width" => 300
      })

    assert config.accent == "#0f766e"
    assert config.email == "j@example.nl"
    assert config.max_width == 300
  end

  test "sleutels met een spatie erin worden genegeerd" do
    assert Config.from_map(%{"photo focus" => "top"}, warn: false).photo_focus == "center 25%"
    assert Config.from_map(%{"photo_focus" => "top"}).photo_focus == "top"
  end

  test "onbekende sleutels worden genegeerd" do
    assert Config.from_map(%{"onzin" => 1}, warn: false).accent == "#1d4ed8"
  end

  test "een kleur zonder hashtag wordt geaccepteerd" do
    assert Config.from_map(%{"accent" => "1d4ed8"}).accent == "#1d4ed8"
  end

  test "een ongeldige kleur valt terug op de standaard" do
    assert Config.from_map(%{"accent" => "rood"}, warn: false).accent == "#1d4ed8"
  end

  test "max_width mag een getal zijn" do
    assert Config.from_map(%{"max_width" => "250"}).max_width == 250
    assert Config.from_map(%{"max_width" => -5}).max_width == 480
  end

  test "links worden een lijst van label en url" do
    config = Config.from_map(%{"links" => [%{"label" => "GitHub", "url" => "https://g.nl"}]})

    assert config.links == [%{label: "GitHub", url: "https://g.nl"}]
  end

  test "een link zonder label gebruikt de url als label" do
    config = Config.from_map(%{"links" => [%{"url" => "https://g.nl"}]})

    assert config.links == [%{label: "https://g.nl", url: "https://g.nl"}]
  end

  test "contactgegevens komen in een vaste volgorde" do
    config = %Config{email: "j@example.nl", phone: "06", location: "Utrecht"}

    assert Enum.map(Config.contact_items(config), &elem(&1, 0)) == [
             :email,
             :phone,
             :location
           ]
  end

  test "lege contactgegevens vallen weg" do
    assert Config.contact_items(%Config{email: nil, location: "  "}) == []
  end

  test "slug maakt een vergelijkbare sleutel van een kop" do
    assert Config.slug("Vaardigheden") == "vaardigheden"
    assert Config.slug("Vaardigheden & Kennis") == "vaardigheden-kennis"
    assert Config.slug("Werkervaring") == "werkervaring"
  end

  test "zonder secties blijft de volgorde leeg" do
    assert Config.section_order(%Config{}) == []
    assert Config.section_order(%Config{sections: ["Werkervaring"]}) == ["werkervaring"]
  end

  test "kapotte json geeft een duidelijke foutmelding" do
    path =
      Path.join(System.tmp_dir!(), "kapotte-config-#{System.unique_integer([:positive])}.json")

    File.write!(path, "{ geen json }")

    assert_raise RuntimeError, ~r/geen geldige json/, fn -> Config.load(path) end

    File.rm(path)
  end
end
