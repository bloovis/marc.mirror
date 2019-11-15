#!/usr/bin/env ruby

class LocNameConverter
  @@number_to_name = {
     "001" => "control",
     "003" => "control_id",
     "005" => "date",
     "007" => "physical_fixed",
     "008" => "fixed",
     "020" => "isbn",
     "040" => "catsource",
     "049" => "local_holdings",
     "050" => "loc",
     "082" => "dewey",
     "035" => "system",
     "100" => "name",
     "245" => "title",
     "246" => "varying_title",
     "250" => "edition",
     "257" => "country",
     "260" => "publication",
     "264" => "production",
     "300" => "physical",
     "336" => "content",
     "337" => "media",
     "338" => "carrier",
     "340" => "medium",
     "344" => "sound",
     "346" => "video",
     "347" => "digital",
     "380" => "form_of_work",
     "500" => "note",
     "508" => "credits",
     "510" => "citation",
     "511" => "participant",
     "520" => "summary",
     "538" => "system_details",
     "546" => "language",
     "600" => "subject_name",
     "610" => "subject_corporate",
     "611" => "subject_meeting",
     "630" => "subject_title",
     "650" => "subject_topical",
     "651" => "subject_geographic",
     "655" => "subject_genre",
     "700" => "added_name",
     "710" => "added_corporate",
     "730" => "added_title",
     "942" => "kohatype"
  }

  @@name_to_number = {}

  def initialize
    @@number_to_name.each do |k, v|
      @@name_to_number[v] = k
    end
  end

  def get_name(number)
    @@number_to_name[number]
  end

  def get_number(name)
    @@name_to_number[name]
  end
end
