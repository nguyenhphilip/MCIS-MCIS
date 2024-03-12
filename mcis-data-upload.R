library(readxl)
library(tidyverse)
library(janitor)
library(stringr)
library(lubridate)
library(openxlsx)

# from the sheets with 53
## Drop the minute calculations;
# from the sheets with 49
## Drop Responder 3
## Add enrollment to SS

col_names <- read_csv("column_names49.csv")
  
# read_xlsx("36-Washington County Health & Human Services (Washington)/MCIS/Q2/q2-mcis-wash-copy.xlsx",
#           skip = 3,
#           sheet = 1) |>
#   mutate(dispatch_request_t = str_extract(`Dispatch Request Date & Time\r\nMM/DD/YY HH:MM (24 hr/military time)`,
#                                            "(..):(..):(..)"),
#          dispatch_t = str_extract(`Dispatch Date & Time\r\nMM/DD/YY HH:MM (24 hr/military time)`,
#                                    "(..):(..):(..)"),
#          arrival_t = str_extract(`Arrival on Scene Date & Time\r\nMM/DD/YY HH:MM (24 hr/military time)`,
#                                   "(..):(..):(..)"),
#          engage_t = str_extract(`Engagement w/ Client Date & Time\r\nMM/DD/YY HH:MM (24 hr/military time)`,
#                                   "(..):(..):(..)"),
#          depart_t = str_extract(`MCIT Departure Date & Time\r\nMM/DD/YY HH:MM (24 hr/military time)`,
#                                  "(..):(..):(..)"),
#          ###
#          ###
#          dispatch_request_dt = as_datetime(paste(`Date of Data Entry\r\nMM/DD/YYYY`, dispatch_request_t)),
#          dispatch_dt = as_datetime(paste(`Date of Data Entry\r\nMM/DD/YYYY`, dispatch_t)),
#          arrival_dt = as_datetime(paste(`Date of Data Entry\r\nMM/DD/YYYY`, arrival_t)),
#          engage_dt = as_datetime(paste(`Date of Data Entry\r\nMM/DD/YYYY`, engage_t)),
#          depart_dt = as_datetime(paste(`Date of Data Entry\r\nMM/DD/YYYY`, depart_t))
#          ) |> 
#   writexl::write_xlsx("36-Washington County Health & Human Services (Washington)/MCIS/Q2/q2-wash-mcis-copy-fin.xlsx")

# For renaming columns to match redcap codebook

col_renames <- c(
  "record_id" = "record_id",
  "redcap_repeat_instance" = "repeat_instance",
  "mcis_team" = "mobile_crisis_team",
  "mc_responders_1" = "responder_number_1",
  "mc_responders_2" = "responder_number_2",
  "endpoint_dispatch" = "endpoint_of_dispatch",
  "legal_first_name" = "legal_first_name",
  "preferred_first_name" = "preferred_first_name_leave_blank_if_same_as_legal_first_name",
  "last_name" = "last_name",
  "dob" = "date_of_birth_mm_dd_yyyy",
  "repeat_dispatch" = "repeat_dispatch",
  "gender" = "gender",
  "sexual_orientation" = "sexual_orientation_optional",
  "race_ethnicity1" = "race_ethnicity_number_1",
  "race_ethnicity2" = "race_ethnicity_number_2",
  "race_ethnicity3" = "race_ethnicity_number_3",
  "idd_status" = "known_i_dd",
  "military_status" = "military_veteran_status",
  "dhs_status" = "dhs_custody_or_guardianship",
  "living_situation" = "current_living_situation",
  "primary_insurance" = "primary_insurance",
  "second_insurance" = "secondary_insurance",
  "home_zip" = "home_zip_code",
  "dispatch_requester" = "caller_requesting_dispatch",
  "dispatch_location" = "dispatch_location",
  "dispatch_zip" = "dispatch_zip_code",
  "request_datetime" = "dispatch_request_date_time_mm_dd_yy_hh_mm_military_time",
  "dispatch_datetime" = "dispatch_date_time_mm_dd_yy_hh_mm_military_time",
  "arrival_datetime" = "arrival_on_scene_date_time_mm_dd_yy_hh_mm_military_time",
  "engagement_datetime" = "engagement_w_client_date_time_mm_dd_yy_hh_mm_military_time",
  "departure_datetime" = "mcit_departure_date_time_mm_dd_yy_hh_mm_military_time",
  "reason_for_dispatch1" = "reason_for_dispatch_number_1",
  "reason_for_dispatch2" = "reason_for_dispatch_number_2",
  "reason_for_dispatch3" = "reason_for_dispatch_number_3",
  "reason_for_dispatch4" = "reason_for_dispatch_number_4",
  "reason_for_dispatch5" = "reason_for_dispatch_number_5",
  "abuse_reported" = "abuse_reported",
  "ems_scene" = "ems_on_scene",
  "le_scene" = "law_enforcement_on_scene",
  "client_language" = "client_preferred_language",
  "language_need_met" = "language_need_met",
  "custody" = "custody_required",
  "disposition" = "disposition",
  "services_72hour" = "services_received_within_72_hours",
  "ref_stabilization_services" = "referral_to_stabilization_services_under_20_y_o",
  "enr_stabilization_services" = "enrollment_in_stabilization_services_under_20_years_old_only"
)

# HELPER FUNCTIONS

## The excel sheets have extra empty rows in them. 
## This function takes in a DF and drops the extra empty rows.

 clean_xlsx <- function(df){
  df[rowSums(is.na(df)) != ncol(df),]
}

## LOOKUP Table - for converting labels into numerically coded values

lookup <- read_csv("a-data-template.csv")

conv <- read_csv("a-need2convert.csv")

## Function to RECODE raw values to coded values

recode_col <- function(x) {
  
  recode_vec <- lookup |>
    filter(variable_name == cur_column()) |>
    pull(value, name = label)
  
  dplyr::recode(x, !!!recode_vec)
}

# recode_col2 <- function(x) {
#   
#   recode_vec <- conv |>
#     filter(variable == cur_column()) |>
#     pull(value, name = label)
#   
#   dplyr::recode(x, !!!recode_vec)
# }

read_mapped_csv <- function(x){
  f <- read_csv(x, col_types = cols(.default = "c"))
  clean_f <- f |> mutate(quarter = str_extract(x, "Q[1-4]"))
  clean_f
}

### variable names

cols_vec <- unique(lookup$variable_name)

## Check directories, read xlsx, clean, save as csv.

home_dir <- list.dirs(full.names = F)

zip_codes <- read_xlsx("OR Zip Codes and Service Areas and their ORH Urban Rural Frontier Designation 6-7-23.xlsx") |>
  select(`Zip Code`, County) |>
  rename("dispatch_zip" = `Zip Code`,
         "mcis_county" = "County") |>
  mutate(mcis_county = str_to_title(mcis_county))

## create large df

d <- list()

# MCIS

for (dir in home_dir){
  if(grepl("(MCIS)/Q[1234]", dir)){
    for (f in list.files(dir, pattern = ".xlsx")){
      dir_n <- paste(dir, f, sep = "/")
      print(paste("Currently:", dir_n))
      file_name <- dir_n
      
      # exceptions for these counties
      
      if(grepl("18-Klamath Basin Behavioral Health", dir) | grepl("28-Multnomah County Behavioral Health Division", dir)){
        df <- read_xlsx(file_name, sheet = 1) |> 
          clean_names()
      } else {
        df <- read_xlsx(file_name, skip = 3, sheet = 1) |> 
          clean_names()
      }
      
      if(ncol(df) > 49){
        df <- df |>
          select(-contains("minute"))
        
        # rename columns/variables
        names(df) <- col_names$variable_name
        
        # drop extra rows, clean data
        clean_df <- clean_xlsx(df) |>
          rename(any_of(col_renames)) |>
          mutate(across(-contains("datetime"), as.character)) |> 
          mutate(across(all_of(cols_vec), recode_col)) |>
          # mutate(across(all_of(cols_vec), recode_col2)) |>
          mutate(across(everything(), ~ str_replace(., "NULL", ""))) |>
          mutate_all(na_if, "") |>
          mutate(legal_first_name = str_extract(legal_first_name, ".*[A-Z].*[a-z].*"),
                 home_zip = str_extract(home_zip, "\\d{5}"))
      } else {
        df <- clean_xlsx(df) |>
          select(-"responder_number_3") |>
          add_column("enr_stabilization_services" = NA)
        # print(paste(dir, "Equal 49"))
        names(df) <- col_names$variable_name
        clean_df <- df |>
          rename(any_of(col_renames)) |>
          mutate(across(-contains("datetime"), as.character)) |>
          mutate(across(all_of(cols_vec), recode_col)) |>
          # mutate(across(all_of(cols_vec), recode_col2)) |>
          mutate(legal_first_name = str_extract(legal_first_name, ".*[A-Z].*[a-z].*"),
                 home_zip = str_extract(home_zip, "\\d{5}"))
      }
    
      # SAVE DATA #
      
      final_df <- clean_df |> 
        select(-"event_name", -"date_of_data_entry_mm_dd_yyyy") |>
        mutate(redcap_repeat_instance = "new",
               redcap_repeat_instrument = "mobile_crisis_intervention") |>
        mutate(across(-contains("datetime"), ~na_if(., '\"\"')))

      d[[dir]] <- final_df
      
      cleaned_name <- paste(dir, paste0(str_remove(f, ".xlsx"), ".csv"), sep = "/")
      cleaned_split <- str_split_1(cleaned_name, pattern = "/")
      fin_name <- paste(cleaned_split[3], paste(cleaned_split[1], cleaned_split[4], sep = "__"), sep = "__")
      cleaned_fname <- paste("0-Cleaned Data-2023/MCIS/2-pre/", fin_name, sep = "")
      write_csv(final_df, file = cleaned_fname, na = "")
    }
  }
}

tbl <-
  list.files(path = "0-Cleaned Data-2023/MCIS/2-pre/",
             pattern = "*.csv", full.names = T) |>
  map_df(~read_mapped_csv(.))

fin_tbl <- rowid_to_column(tbl) |>
  group_by(legal_first_name, last_name, dob) |>
  mutate(grp_id = cur_group_id()) |>
  ungroup() |>
  mutate(record_id = if_else(is.na(legal_first_name), as.integer(paste0(grp_id, rowid)), grp_id)) |>
  filter(!is.na(mcis_team)) |>
  mutate(complete = "2",
         legal_first_name = str_to_title(legal_first_name),
         preferred_first_name = str_to_title(preferred_first_name),
         last_name = str_to_title(last_name),
         client_language = str_to_title(client_language)) |>
  left_join(zip_codes, "dispatch_zip") |>
  mutate(dob = as_date(dob),
         # CLEAN THESE MOTHERFUCKERS
         abuse_reported = case_match(abuse_reported,
                                     "no" ~ "No",
                                     "yes" ~ "Yes",
                                     "NO" ~ "No",
                                     "Information Currently not being collected" ~ NA,
                                     .default = abuse_reported),
         custody = case_match(custody,
                              "No custody required" ~ "No Custody Required",
                              "Directors Custody" ~ "Director's Custody",
                              "Director's custody" ~ "Director's Custody",
                              "Police custody" ~ "Police Custody",
                              "no custody required" ~ "No Custody Required",
                              "No Custody required" ~ "No Custody Required",
                              "No custody Required" ~ "No Custody Required",
                              "police custody" ~ "Police Custody",
                              "director's custody" ~ "Director's Custody",
                              "Directors custody" ~ "Director's Custody",
                              .default = custody),
         dhs_status = case_match(dhs_status, 
                                 "Did not ask" ~ "Did Not Ask",
                                 "Client unable to answer" ~ "Client Unable to Answer",
                                 "no" ~ "No",
                                 "Client declined to answer" ~ "Client Declined to Answer",
                                 "yes" ~ "Yes",
                                 "did not ask" ~ "Did Not Ask",
                                 "NO" ~ "No",
                                 .default = dhs_status),
         dispatch_location = case_match(dispatch_location,
                                        "10" ~ NA,
                                        "ED" ~ "Emergency Department (ED)",
                                        "Community/public setting" ~ "Community/Public Setting",
                                        "Outpatient clinic" ~ "Outpatient Clinic",
                                        "Public Services Building -PSB" ~ "Community/Public Setting",
                                        "Hospital (mobile)" ~ "Medical Hospital",
                                        "Public Area (mobile)" ~ "Community/Public Setting",
                                        "Jail (other)" ~ "Jail",
                                        "Residence (mobile)" ~ "Private Residence",
                                        "Public Building (mobile)" ~ "Community/Public Setting",
                                        "Business (mobile)" ~ "Community/Public Setting",
                                        "999" ~ "Other",
                                        "65" ~ "Other",
                                        "other" ~ "Other",
                                        "jail" ~ "Jail",
                                        "private residence" ~ "Private Residence",
                                        "ed" ~ "Emergency Department (ED)",
                                        "community/public setting" ~ "Community/Public Setting",
                                        "Ed" ~ "Emergency Department (ED)",
                                        "Residence (Mobile Crisis)" ~ "Private Residence",
                                        "Public Building (Mobile Crisis)" ~ "Community/Public Setting",
                                        .default = dispatch_location),
         dispatch_requester = case_match(dispatch_requester,
                                         "05=School" ~ "Other",
                                         "06=Community Housing" ~ "Other",
                                         "08=Community-based MH and/or SA Provider" ~ "Bystander/Community Member",
                                         "09=Local MH Authority/Community MH Program" ~ "Other",
                                         "12=Private Health Professional (Primary Care Provider, Physician, Psychiatrist, Hospital, Primary Health Home, etc.)" ~ "Emergency Department or Hospital Personnel",
                                         "17=Jail - city or county" ~ "Law Enforcement Officer/Dispatch",
                                         "28=Family/Friend" ~ "Other Family of Identified Client",
                                         "32=Crisis/Helpline" ~ "988 Dispatcher",
                                         "34=Other" ~ "Other",
                                         "emergency department or hospital personnel" ~ "Emergency Department or Hospital Personnel",
                                         "Emergency Dept or Hospital Personnel" ~ "Emergency Department or Hospital Personnel",
                                         "other" ~ "Other",
                                         "Other Attorney" ~ "Other",
                                         "Other CCMH Treatment Provider" ~ "Other",
                                         "Other Community Action Team." ~ "Other",
                                         "Other CPCCO Case Manager" ~ "Other",
                                         "Other Family of Identified Client()" ~ "Other Family of Identified Client",
                                         "Other ITS team" ~ "Other",
                                         "Other Mental health service provider" ~ "Other",
                                         "Other Community Action Team." ~ "Other",
                                         "Other St Helens Library Director." ~ "Other",
                                         "Other Substance abuse treatment provider" ~ "Other",
                                         "Other St Helens HS" ~ "Other",
                                         "Other Primary Therapist" ~ "Other",
                                         "Other: Father of Ali asked for Felicia Ridings to respond" ~ "Other",
                                         "Other: Eric requested crisis check in" ~ "Other",
                                         "Other Plymouth School administrative staff." ~ "Other",
                                         "Significant Other/Spouse of Client" ~ "Significant Other/Spouse of Identified Client",
                                         "Other(Clinician)" ~ "Other",
                                         "Other(Baker County Jail)" ~ "Other",
                                         "Other(Probation)" ~ "Other",
                                         "Other(School)" ~ "Other",
                                         "Other(High School)" ~ "Other",
                                         "Other(School superintendent)" ~ "Other",
                                         "Other(school)" ~ "Other",
                                         "Police or sheriff - local, state" ~ "Law Enforcement Officer/Dispatch",
                                         "School" ~ "Other",
                                         .default = dispatch_requester),
         disposition = case_match(disposition,
                                  "Jail" ~ "Arrest",
                                  "Remained in Community-Emergency Department Diversion" ~ "Remained in the Community",
                                  "Remained in Community" ~ "Remained in the Community",
                                  "Emergency department" ~ "Emergency Department",
                                  "Remained in the community" ~ "Remained in the Community",
                                  "Crisis walk-in center" ~ "Crisis Walk-In Center",
                                  "Crisis Walk-in Center" ~ "Crisis Walk-In Center",
                                  "Referred to Acute Care" ~ "Acute Care",
                                  "Returned to Community" ~ "Remained in the Community",
                                  "Remained at Emergency Department" ~ "Emergency Department",
                                  "Sent to Emergency Department" ~ "Emergency Department",
                                  "Remained in Jail" ~ "Other",
                                  "Diverted from Emergency Department (ED)" ~ "Emergency Department",
                                  "Crisis Respite" ~ "Respite",
                                  "Arrested" ~ "Arrest",
                                  "Sobering or detox facility" ~ "Sobering or Detox Facility",
                                  "remained in the community" ~ "Remained in the Community",
                                  "emergency department" ~ "Emergency Department",
                                  "other" ~ "Other",
                                  "Remained In Community" ~ "Remained in the Community",
                                  "arrest" ~ "Arrest",
                                  "Legacy Mt. Hood" ~ "Emergency Department",
                                  "OHSU" ~ "Emergency Department",
                                  "Portland Adventist" ~ "Other",
                                  "Portland Providence" ~ "Other",
                                  "Unity Center for Behavioral Health" ~ "Other",
                                  "Legacy Good Samaritan" ~ "Other", 
                                  "Legacy Emanuel" ~ "Other",
                                  "Veterans Administration" ~ "Other",
                                  "Providence Milwaukie" ~ "Other",
                                  "Providence St. Vincent" ~ "Other",
                                  .default = disposition),
         ems_scene = case_match(ems_scene,
                                "NO" ~ "No",
                                "YEs" ~ "Yes",
                                "no" ~ "No",
                                "yes" ~ "Yes",
                                .default = ems_scene),
         endpoint_dispatch = case_match(endpoint_dispatch,
                                        "Client Declined to Engage" ~ "Client declined to engage",
                                        "Did Not Make Contact Due to Safety Issues" ~ "Did not make contact due to safety issues",
                                        "Did not make contact due to safety issue" ~ "Did not make contact due to safety issues",
                                        "Dispatch cancelled prior to arrival" ~ "Dispatch cancelled before arrival",
                                        "Engage Client" ~ "Engaged client",
                                        "Engaged Client" ~ "Engaged client",
                                        "No Document Found" ~ "Other",
                                        "Unable to locate" ~ "Unable to locate client",
                                        .default = endpoint_dispatch),
         enr_stabilization_services = case_match(enr_stabilization_services,
                                                 "NO" ~ "No",
                                                 "no" ~ "No",
                                                 "unknown" ~ "Unknown",
                                                 "yes" ~ "Yes",
                                                 .default = enr_stabilization_services),
         gender = case_match(gender,
                             "Client declined to answer" ~ "Client Declined to Answer",
                             "Client unable to answer" ~ "Client Unable to Answer",
                             "Did not ask" ~ "Did Not Ask",
                             "MALE" ~ "Male",
                             "MAle" ~ "Male",
                             "male" ~ "Male",
                             "X" ~ NA,
                             "female" ~ "Female",
                             "other" ~ "Other",
                             .default = gender),
         idd_status = case_match(idd_status,
                                 "NO" ~ "No",
                                 "Unable to determine" ~ "Unable to Determine",
                                 "no" ~ "No",
                                 "unable to determine" ~ "Unable to Determine",
                                 "yes" ~ "Yes",
                                 .default = idd_status),
         language_need_met = case_match(language_need_met,
                                        "YES" ~ "Yes",
                                        "YEs" ~ "Yes",
                                        "yes" ~ "Yes",
                                        .default = language_need_met),
         le_scene = case_match(le_scene,
                               "N" ~ "No",
                               "NO" ~ "No",
                               "Y" ~ "Yes",
                               "YES" ~ "Yes",
                               "YEs" ~ "Yes",
                               "no" ~ "No",
                               "yes" ~ "Yes",
                               .default = le_scene),
         living_situation = case_match(living_situation,
                                       "DHS Temporary Lodging/Shelter" ~ "Not Listed",
                                       "Did not ask" ~ "Did Not Ask",
                                       "Private Residence (At Home)" ~ "Private Residence (at home)",
                                       "Private Residence (With Non-Relative)" ~ "Private Residence (with non-relative)",
                                       "Private Residence (With Relative)" ~ "Private Residence (with relative)",
                                       "Private Residence (with Relatives)" ~ "Private Residence (with relative)",
                                       "Private Residence with Relative" ~ "Private Residence (with relative)",
                                       "Private residence (with relative)" ~ "Private Residence (with relative)",
                                       "Private residence - w/parent relative adult child(ren)" ~ "Private Residence (with relative)",
                                       "Residential Facility (BRS)" ~ "Other DHS Setting",
                                       "Residential Treatment Facility/Home" ~ "Residential Facility",
                                       "Supportive Housing (Scattered Site)" ~ "Supportive Housing (scattered site)",
                                       "Supportive Housing (congregate setting)" ~ "Supportive Housing (congregate site)",
                                       "jail" ~ "Jail",
                                       "Private Residence" ~ "Other Private Residence",
                                       "private residence (at home)" ~ "Private Residence (at home)",
                                       "transient/homeless" ~ "Transient/Homeless",
                                       "Other" ~ NA,
                                       "Unknown" ~ NA,
                                       .default = living_situation),
         mc_responders_1 = case_match(mc_responders_1,
                                      "PEER" ~ "Peer",
                                      "agrigg" ~ "Other",
                                      "cstevenson" ~ "Other",
                                      "lreddington" ~ "Other",
                                      "qmhp" ~ "QMHP",
                                      .default = mc_responders_1),
         mc_responders_2 = case_match(mc_responders_2,
                                      "NONE" ~ NA,
                                      "PEer" ~ "Peer",
                                      "Qmhp" ~ "QMHP",
                                      "none" ~ NA,
                                      "other" ~ "Other",
                                      "peer" ~ "Peer",
                                      "qmha" ~ "QMHA",
                                      "qmhp" ~ "QMHP",
                                      .default = mc_responders_2),
         military_status = case_match(military_status,
                                      "Unknown" ~ NA,
                                      "Client Declinet to Answe" ~ "Client Declined to Answer",
                                      "Client declined to answer" ~ "Client Declined to Answer",
                                      "Client unable to answer" ~ "Client Unable to Answer",
                                      "Did Not ask" ~ "Did Not Ask",
                                      "Did not Ask" ~ "Did Not Ask",
                                      "Did not ask" ~ "Did Not Ask",
                                      "NO" ~ "No Service History",
                                      "No service history" ~ "No Service History",
                                      "Not a veteran, current/former guard/reserve" ~ "No, but Current or Former Guard/Reserve Military",
                                      "Unk" ~ NA,
                                      "Veteran, Current or Former Active Duty Military" ~ "Yes, Veteran and Current or Former Active Duty Military",
                                      "Veteran, Current or Former Guard/Researve Military" ~ NA,
                                      "Veteran, current/former active duty" ~ "Yes, Veteran and Current or Former Active Duty Military",
                                      "Veteran, no specified Branch of Service" ~ "Yes, Veteran and not specified Branch of Service",
                                      "Veteran, no specified branch" ~ "Yes, Veteran and not specified Branch of Service",
                                      "Yes, Veteran and current or former active duty military" ~ "Yes, Veteran and Current or Former Active Duty Military",
                                      "Yes, Veteran and current or former guard/reserve military" ~ "Yes, Veteran and Current or Former Guard/Reserve Military",
                                      "Yes, Veteran. Branch of Service Not Specified" ~ "Yes, Veteran and not specified Branch of Service",
                                      "did not ask" ~ "Did Not Ask",
                                      "no" ~ "No Service History",
                                      "no service history" ~ "No Service History",
                                      "unk" ~ NA,
                                      "yes" ~ "Yes, Veteran and not specified Branch of Service",
                                      .default = military_status),
         primary_insurance = case_match(primary_insurance,
                                        "Unknown" ~ NA,
                                        "Did not ask" ~ "Did Not Ask",
                                        "Not listed" ~ "Not Listed",
                                        "Oregon medicaid" ~ "Oregon Medicaid",
                                        "Oregon medicare" ~ "Oregon Medicare",
                                        "Other State Medicare/Medicaid" ~ "Other state Medicare/Medicaid",
                                        "Other State/Medicare/Medicaid" ~ "Other state Medicare/Medicaid",
                                        "Review-Undefined" ~ NA,
                                        "not listed" ~ "Not Listed",
                                        "oregon Medicaid" ~ "Oregon Medicaid",
                                        "oregon Medicare" ~ "Oregon Medicare",
                                        "oregon medicaid" ~ "Oregon Medicaid",
                                        "oregon medicare" ~ "Oregon Medicare",
                                        "private/commercial" ~ "Private/Commercial",
                                        "uninsured" ~ "Uninsured",
                                        .default = primary_insurance),
         race_ethnicity1 = case_match(race_ethnicity1,
                                      "Unknown" ~ NA,
                                      "20 White (Non-Hispanic)" ~ "Other White",
                                      "Another Hispanic, Latino/a, or Spanish Origin" ~ "Other Hispanic or Latino/a/x",
                                      "Asian" ~ "Other Asian",
                                      "Black or African American" ~ "Other Black",
                                      "Black/African American" ~ "Other Black",
                                      "Did not ask" ~ "Did Not Ask",
                                      "Hispanic or Latino/a" ~ "Other Hispanic or Latino/a/x",
                                      "Native American" ~ "American Indian",
                                      "Non-Hispanic or Latino/a" ~ "Other", 
                                      "Other Single Race" ~ "Other",
                                      "Other white" ~ "Other White",
                                      "Patient Refused" ~ "Client Declined to Answer",
                                      "Two or More Races" ~ NA,
                                      "White" ~ "Other White",
                                      "did Not Ask" ~ "Did Not Ask",
                                      "other" ~ "Other",
                                      "other White" ~ "Other White",
                                      "other white" ~ "Other White",
                                      "western european" ~ "Western European",
                                      .default = race_ethnicity1),
         race_ethnicity2  = case_match(race_ethnicity2,
                                       "Unknown" ~ NA,
                                       "Black or African American" ~ "Other Black",
                                       "Black/African American"  ~ "Other Black",
                                       "Did not ask" ~ "Did Not Ask",
                                       "Native American" ~ "American Indian",
                                       "Native Hawaiian/Pacific Islander" ~ "Native Hawaiian",
                                       "Other Single Race" ~ "Other",
                                       "Other white" ~ "Other White",
                                       "Two or More Races" ~ NA,
                                       "White" ~ "Other White",
                                       .default = race_ethnicity2),
         race_ethnicity3 = case_match(race_ethnicity3,
                                      "Unknown" ~ NA,
                                      "Black or African American" ~ "Other Black",
                                      "Did not ask" ~ "Did Not Ask",
                                      "Native American" ~ "American Indian",
                                      "Other Single Race" ~ "Other",
                                      "White" ~ "Other White",
                                      .default = race_ethnicity3),
         reason_for_dispatch1 = case_match(reason_for_dispatch1,
                                           "Adult interpersonal conflict/violence (protected category)" ~ "Adult interpersonal conflict or violence (protected category)",
                                           "Agitation or disruptive behaivor" ~ "Agitation or disruptive behavior",
                                           "Child Abuse, Neglect or Exploitation" ~ "Child abuse, neglect or exploitation",
                                           "Concerns About Treatment Engagement" ~ "Concerns about treatment engagement",
                                           "Difficulties functioning" ~ "Difficulties Functioning",
                                           "Difficulty Functioning" ~ "Difficulties Functioning",
                                           "Difficulty functioning" ~ "Difficulties Functioning",
                                           "Disorganized Behavior" ~ "Disorganized behavior",
                                           "Disorganized/challenges functioning" ~ "Difficulties Functioning",
                                           "Disorganized/not functioning" ~ "Disorganized behavior",
                                           "Harm/Rick of harm to self" ~ "Harm/Risk of harm to self",
                                           "Harm/Risk of Harm to Others" ~ "Harm/Risk of harm to others",
                                           "Harm/Risk of Harm to Property" ~ "Harm/Risk of harm to property",
                                           "Harm/Risk of Harm to Self" ~ "Harm/Risk of harm to self",
                                           "Harm/Risk of harm to Self" ~ "Harm/Risk of harm to self",
                                           "Harm/risk of harm to others" ~ "Harm/Risk of harm to others",
                                           "Harm/risk of harm to self" ~ "Harm/Risk of harm to self",
                                           "Interpersonal conflict or violence (including child abuse & neglect, dating violence, domestic violence, human trafficking, sexual assault, sexual exploitation, sexual harassment, stalking, bullying, hazing, and elder abuse)" ~ "Adult interpersonal conflict or violence (protected category)",
                                           "Running Away" ~ "Running away",
                                           "SI/HI/Psychosis" ~ "Other",
                                           "Suicidality or Suicide Attempt" ~ "Suicidality or suicide attempt",
                                           "Suicidality or Suicide attempt" ~ "Suicidality or suicide attempt",
                                           "other" ~ "Other",
                                           "paranoia" ~ "Paranoia",
                                           "seeking mental health services" ~ "Seeking mental health services",
                                           "trauma" ~ "Trauma",
                                           .default = reason_for_dispatch1),
         reason_for_dispatch2 = case_match(reason_for_dispatch2,
                                           "Child Abuse, Neglect or Exploitation" ~ "Child abuse, neglect or exploitation",
                                           "Difficulties functioning" ~ "Difficulties Functioning",
                                           "Difficulty functioning" ~ "Difficulties Functioning",
                                           "Disorganized/challenges functioning" ~ "Disorganized behavior",
                                           "Harm/Rick of harm to property" ~ "Harm/Risk of harm to property",
                                           "Harm/Rick of harm to self" ~ "Harm/Risk of harm to self",
                                           "Harm/risk of harm to others" ~ "Harm/Risk of harm to others",
                                           "Harm/risk of harm to self"  ~ "Harm/Risk of harm to self",
                                           "Needing Social Services" ~ "Needing social services",
                                           "Substance Use" ~ "Substance use",
                                           "other" ~ "Other",
                                           "paranoia" ~ "Paranoia",
                                           "suicidality or suicide attempt" ~ "Suicidality or suicide attempt",
                                           "trauma" ~ "Trauma",
                                           .default = reason_for_dispatch2),
         reason_for_dispatch3 = case_match(reason_for_dispatch3,
                                           "Child Abuse, Neglect or Exploitation" ~ "Child abuse, neglect or exploitation",
                                           "Difficulties functioning" ~ "Difficulties Functioning",
                                           "Difficulty functioning" ~ "Difficulties Functioning",
                                           "Disorganized Behavior"  ~ "Disorganized behavior",
                                           "Disorganized/challenges functioning"  ~ "Disorganized behavior",
                                           "Harm/Rick of harm to property" ~ "Harm/Risk of harm to property",
                                           "Harm/Rick of harm to self" ~ "Harm/Risk of harm to self",
                                           "other" ~ "Other",
                                           "paranoia" ~ "Paranoia",
                                           "trauma" ~ "Trauma",
                                           .default = reason_for_dispatch3),
         reason_for_dispatch4 = case_match(reason_for_dispatch4,
                                           "Adult interpersonal conflict/violence (protected category)" ~ "Adult interpersonal conflict or violence (protected category)",
                                           "Child Abuse, Neglect or Exploitation"  ~ "Child abuse, neglect or exploitation",
                                           "Difficulties functioning" ~ "Difficulties Functioning",
                                           "Difficulty functioning" ~ "Difficulties Functioning",
                                           "Disorganized/challenges functioning" ~ "Disorganized behavior",
                                           "Harm/Rick of harm to self"  ~ "Harm/Risk of harm to self",
                                           "other" ~ "Other",
                                           .default = reason_for_dispatch4),
         reason_for_dispatch5 = case_match(reason_for_dispatch5,
                                           "Difficulties functioning" ~ "Difficulties Functioning",
                                           "Difficulty functioning" ~ "Difficulties Functioning",
                                           "English" ~ NA,
                                           "Spanish" ~ NA,
                                           .default = reason_for_dispatch5),
         ref_stabilization_services = case_match(ref_stabilization_services,
                                                 "Information Currently not being collected" ~ NA,
                                                 "NO" ~ "No",
                                                 "no" ~ "No",
                                                 "yes" ~ "Yes",
                                                 .default = ref_stabilization_services),
         repeat_dispatch = case_match(repeat_dispatch,
                                      "No, update demographic info" ~ "No, update demographic information",
                                      "Unknown, update demographic info" ~ "Unknown, update demographic information",
                                      "Yes, skip demographic info" ~ "Yes, skip demographic information",
                                      "Yes, updated demographic info" ~ "Yes, update demographic information",
                                      .default = repeat_dispatch),
         second_insurance = case_match(second_insurance,
                                       "Other State Medicare/Medicaid" ~ "Other state Medicare/Medicaid",
                                       "Tribal Insurance/Indian Health Svces" ~ "Tribal Insurance/Indian Health Services",
                                       "oregon medicaid" ~ "Oregon Medicaid",
                                       "oregon medicare" ~ "Oregon Medicare",
                                        .default = second_insurance),
         services_72hour = case_match(services_72hour,
                                      "N/A: follow up declined/no engagement" ~ "No: follow up declined/no engagement",
                                      "N/A: hand off to another provider/system" ~ "No: hand off to another provider/system",
                                      "N/A: no follow up needed" ~ "No: no follow up needed",
                                      "No: Follow up declined" ~ "No: follow up declined/no engagement",
                                      "No: Handoff to another provider/system" ~ "No: hand off to another provider/system",
                                      "No: No follow up needed" ~ "No: no follow up needed",
                                      "No: follow up declined" ~ "No: follow up declined/no engagement",
                                      "No: handoff to another provider/system" ~ "No: hand off to another provider/system",
                                      "No: no Follow up needed" ~ "No: no follow up needed",
                                      "No: other" ~ "No: Other",
                                      "no: other" ~ "No: Other",
                                      "Yes: After 72 hours" ~ "Yes: after 72 hours",
                                      "Yes: Within 72 hours" ~ "Yes: within 72 hours",
                                      "yes" ~ "Yes",
                                      "yes: after 72 hours" ~ "Yes: after 72 hours",
                                      "yes: within 72 hours" ~ "Yes: within 72 hours",
                                      .default = services_72hour),
         sexual_orientation = case_match(sexual_orientation,
                                         "BiSexual" ~ "Bisexual",
                                         "Client declined to answer" ~ "Client Declined to Answer",
                                         "Client unable to answer" ~ "Client Unable to Answer",
                                         "Did not ask" ~ "Did Not Ask",
                                         "Heterosexual" ~ "Straight",
                                         "Unknown" ~ NA,
                                         "Not asked" ~ "Did Not Ask",
                                         "Not listed" ~ "Not Listed",
                                         "Refused" ~ "Client Declined to Answer",
                                         "Same-gender loving" ~ "Same-Gender Loving",
                                         "Same-sex loving" ~ "Same-Sex Loving",
                                         "straight" ~ "Straight",
                                         "Other" ~ NA,
                                         .default = sexual_orientation)
         ) |>
  mutate(across(contains("_datetime"), as_datetime))

# length(unique(fin_tbl$record_id))
z <- lapply(fin_tbl |> select(-contains("date"),
                          -contains("name"),
                          -"record_id",
                          -"dob", -"age",
                          -"redcap_repeat_instrument",
                          -"grp_id",
                          -"mcis_team",
                          -"complete",
                          -"rowid",
                          -"redcap_repeat_instance",
                          -"quarter",
                          -"client_language",
                          -"mcis_county",
                          -contains("zip")), unique)

# fin_tbl |> filter(quarter == "Q4") |> select(mcis_team, contains("zip")) |> View()

baddie_detector <- function(x, fin_tbl){
  fin_tbl |>
    filter(!(!!sym(x) %in% lookup$value) & !(!!sym(x) %in% lookup$label)) |> 
    filter(!is.na(!!sym(x))) |> 
    select(mcis_team, !!sym(x)) |> 
    rename(value = mcis_team) |>
    inner_join(lookup |> filter(variable_name == "mcis_team"), by = "value") |>
    rename(team = label) |>
    mutate(variable = x,
           value = !!sym(x)) |>
    unique()
}

baddies <- z |>
  names() |>
  map(~baddie_detector(., fin_tbl)) |>
  map_df(~. |> select(team, variable, value)) |>
  arrange(team)

View(baddies)

# baddies |> select(variable, value) |> unique() |> arrange(variable, value) |> View()

# baddies |> write_csv(file = paste0(Sys.Date(), "-mcis_data_issues.csv"))

# plyr::ldply(z, cbind) |> View() # |> write_csv("a-need2convert.csv")

# Upload to REDCap

library(redcapAPI)

redcap_url <- "https://octri.ohsu.edu/redcap/api/"
mcis_token <- read_csv("~/Desktop/MCIS_MCSS/RCtok.csv") |> filter(project == "mcis")

rcon <- redcapConnection(url=redcap_url, token=mcis_token$token[1])

# fn <- exportFieldNames(rcon)
## To delete records ##

# r <- tibble(exportRecordsTyped(rcon, batch_size = 500))
# deleteRecords(rcon, unique(r$record_id))

# IMPORT

importRecords(rcon,
              # CHANGE THIS
              fin_tbl |> filter(mcis_team == "21" & quarter == "Q4"),
              overwriteBehavior = c("normal", "overwrite"), 
              batch.size = 500,
              returnData = F,
              force_auto_number = F,
              api_param = list(complete = T))

# EXPORT as XLSX to X Drive

# read_xlsx("18-Klamath Basin Behavioral Health (Klamath)/MCIS/Q3/MCIS Data Quarter 3 2023.xlsx") |>
#   mutate(`Date of Birth` = as_date(ymd_hms(`Date of Birth`)),
#          `Data Entry Date` = as_date(ymd_hms(`Data Entry Date`))) |> 
#   writexl::write_xlsx("18-Klamath Basin Behavioral Health (Klamath)/MCIS/Q3/MCIS Data Quarter 3 2023.xlsx")

# fin_tbl |> skimr::skim()

r <- tibble(exportRecordsTyped(rcon, batch_size = 500))

#x_path <- "~/../../private/tmp/nguphiliVolumes/OHSU/OHSU Shared/Restricted/SHARED/PSYCH/Child Psych Clinic/DAETA Team/MRSS and 988/MCIS Quarterly Reports/Tableau/"
save_name <-"2023_Q2-Q4_Tableau Data.xlsx"
# openxlsx::write.xlsx(r, paste0(x_path, save_name))

openxlsx::write.xlsx(r, paste0(save_name))
# read_xlsx("Tableau Data.xlsx")
