add a new page to show all sentence of a course to this page.
user can play audio of this course and the current sentence should be highlighted.
when user tap any sentence, the current learning page of sentence will be showed.


# Feature: Course Sentences Overview Page

# Objective: 

Create a new page that displays all sentences for a selected course, enabling users to play the course audio and navigate to individual sentence learning pages.

# User Stories:

As a user, I want to see all sentences belonging to a specific course on a dedicated page.
As a user, I want to be able to play an audio narration of all sentences in the course sequentially from this page.
As a user, I want the sentence currently being read in the audio to be visually highlighted in the page.
As a user, I want to be able to tap on any sentence in the page to playback the audio of the sentence tapped.
As a user, I want to be able to tap a button in the page to navigate directly to its detailed learning page.


# Acceptance Criteria:

## Page Implementation:

A new route and corresponding page component are created.
The page fetches and displays all sentences for a given course ID.
Each sentence is displayed as a distinct, tappable item in the page.

# Audio Playback:

A play/pause button is available to control the audio playback for the entire course.
Audio playback progresses through the sentences in their listed order.

# Sentence Highlighting:

As the audio plays, the sentence currently being spoken is visually distinguished (e.g., different background color, bold text).
Highlighting updates dynamically as the audio progresses to the next sentence.

# State Management:

Audio playback position and highlighting should be correctly managed, even if the user scrolls the list.
If the user navigates away and returns (if feasible within session), the playback state/position might be optionally preserved.


# Technical Considerations (Optional Prompts for Developer):

How will the audio for the entire course be sourced or concatenated?
What mechanism will be used to synchronize audio playback with sentence highlighting (e.g., timestamped transcript, events)?
How will the list of sentences be efficiently rendered, especially for long courses?
Consider accessibility: keyboard navigation for sentence selection and playback control.