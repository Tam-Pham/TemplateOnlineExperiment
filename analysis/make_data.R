library(rjson)


data_path <- "../data/"
data <- data.frame()  # Initialize empty dataframe


# Define Preprocessing functions ------------------------------------------

clean_object <- function(screen) {
  screen[names(screen)[sapply(screen, is.null)]] <- NA
  screen
}

preprocess_session_info <- function(df) {
  names(df) <- tools::toTitleCase(names(df))
  df$Duration_Consent <- df$Rt
  df[c("Button_pressed", "Stimulus", "Screen" ,"Rt", "Internal_node_id", "Time_elapsed", "Trial_index", "Trial_type")] <- NULL
  names(df)[names(df) == "Participant_id"] <- "Participant_ID"
  df
}

preprocess_participant_info_general <- function(df) {
  out <- as.data.frame(df$response[1])
  out <- cbind(out, as.data.frame(df$response[2]))
  out$Duration_InfoGeneral <- df$rt
  out
}

preprocess_participant_info_session <- function(df) {
  out <- as.data.frame(df$response[1])
  out$Duration_InfoSession <- df$rt
  out
}

preprocess_trial <- function(df) {
  df <- df[!stringr::str_detect(names(df), pattern="click_")]  # remove click_x and click_y
  names(df) <- tools::toTitleCase(names(df))
  df[c("Screen" ,"Internal_node_id", "Time_elapsed", "Trial_type")] <- NULL
  names(df)[names(df) == "Rt"] <- "RT"
  df
}

preprocess_question <- function(df, index = NULL, label = NULL){
  if(is.null(label)) {
    label <- gsub("<.*?>", "", df$stimulus)
  }
  if(is.null(index)) {
    index <- paste0("Q", df$trial_index)
  }
  out <- data.frame(Temp = NA)
  out[paste0(index, "_Label")] <- label
  out[paste0(index, "_Score")] <- df$response
  out[paste0(index, "_RT")] <- df$rt
  out$Temp <- NULL
  out
}

preprocess_interactions <- function(x){
  df <- data.frame()
  for(event in x){
    df <- rbind(df, as.data.frame(event))
  }
  names(df) <- tools::toTitleCase(names(df))
  names(df)[names(df) == "Trial"] <- "Trial_index"
  df
}


# Run the preprocessing ---------------------------------------------------

# Loop through all the files
# for(file in list.files(data_path)) {
for(file in list.files(data_path)) {
  # 5th data file marks start of new exp template

  # Read JSON
  rawdata <- rjson::fromJSON(file=paste0(data_path, file))

  # Find interactions (not sure hat to do with them for now)
  for(screen in rawdata){
    if(!is.null(screen$screen) && screen$screen == "question_difficulty") {
      interactions <- preprocess_interactions(rjson::fromJSON(screen$interactions))
    }
  }

  trials <- data.frame()
  info <- data.frame(Temp = 1)

  # Loop through all the "screens" (each screen is recorded as a separate list)
  for(screen in rawdata){
    # print(screen$screen)
    screen <- clean_object(screen)

    if(!is.null(screen$screen) && screen$screen == "session_info") {
      info <- cbind(info, preprocess_session_info(as.data.frame(screen)))
    }
    if(!is.null(screen$screen) && screen$screen == "participant_info_general") {
      info <- cbind(info, preprocess_participant_info_general(screen))
    }
    if(!is.null(screen$screen) && screen$screen == "participant_info_session") {
      info <- cbind(info, preprocess_participant_info_session(screen))
    }
    if(!is.null(screen$screen) && screen$screen == "stimulus") {
      trials <- rbind(trials, preprocess_trial(as.data.frame(screen)))
    }
    if(!is.null(screen$screen) && screen$screen == "question_difficulty") {
      screen$interactions <- NULL
      info <- cbind(info, preprocess_question(as.data.frame(screen), index="Q_Difficulty"))
    }
  }
  info$Temp <- NULL
  data <- rbind(data, cbind(trials, info))
}

write.csv(data, "data.csv", row.names = FALSE)
