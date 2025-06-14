import 'package:flutter/material.dart';
import 'package:muy_english_project/providers/learning_provider.dart';
import 'package:muy_english_project/domain/entities.dart';
import 'package:muy_english_project/providers/service_locator.dart';
import 'package:muy_english_project/utils/utils.dart';
import 'package:simple_logging/simple_logging.dart';
import './course_sentences_overview_ploc.dart'; // Use relative import
import 'package:muy_english_project/pages/learning_page.dart'; // Adjust path if necessary

final _log = Logger('CourseSentencesOverviewPage');

class CourseSentencesOverviewPage extends StatefulWidget {
  final int courseId;

  const CourseSentencesOverviewPage({Key? key, required this.courseId})
      : super(key: key);

  @override
  State<CourseSentencesOverviewPage> createState() =>
      _CourseSentencesOverviewPageState();
}

class _CourseSentencesOverviewPageState
    extends State<CourseSentencesOverviewPage> {
  late Future<Course> _courseFuture;
  late Future<List<Sentence>> _sentencesFuture;
  final _ploc = CourseSentencesOverviewPloc();
  String? _courseName;

  @override
  void initState() {
    super.initState();
    final learningProvider = getIt<LearningProvider>();
    _courseFuture = learningProvider.fetchCourse(widget.courseId);
    _sentencesFuture = learningProvider.fetchSentences(
        SentenceSource(type: SentenceSourceType.course, id: widget.courseId));

    _ploc.audioErrorNotifier.addListener(_showAudioErrorSnackBar);
  }

  void _showAudioErrorSnackBar() {
    if (mounted && _ploc.audioErrorNotifier.value != null) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Remove any existing snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_ploc.audioErrorNotifier.value!),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _ploc.audioErrorNotifier.removeListener(_showAudioErrorSnackBar); // Remove listener first
    _ploc.dispose(); // This line should already be present from PLoC integration step
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Course>(
          future: _courseFuture,
          builder: (context, snapshot) {
            return futureBuilderHelper<Course>(
              context: context,
              snapshot: snapshot,
              onData: (course) {
                // Assign course name here
                // Ensure widget is still mounted before calling setState
                if (mounted) {
                  setState(() {
                    _courseName = course.name;
                  });
                }
                return Text(course.name); // Return the title widget
              },
              onLoadingPlaceholder: const Text('Loading Course...'),
              onErrorPlaceholder: const Text('Error Loading Course'),
              // Removed logger and logId from here as they were not in the original for the AppBar FutureBuilder
            );
          },
        ),
      ),
      body: FutureBuilder<List<Sentence>>(
        future: _sentencesFuture, // This is still initialized in initState
        builder: (context, snapshot) {
          return futureBuilderHelper<List<Sentence>>(
            snapshot: snapshot,
            onDone: () {
              final sentencesList = snapshot.data!;
              _ploc.init(sentencesList);

              if (sentencesList.isEmpty) {
                // Assuming resourceListSectionNoContentLabel exists and is imported
                // For now, using a simple Text widget as placeholder
                return const Center(child: Text('No sentences found for this course.'));
              }

              return ListView.builder(
                itemCount: sentencesList.length,
                itemBuilder: (context, index) {
                  // Ensure 'sentencesList' is in scope, containing the List<Sentence> from the FutureBuilder snapshot.
                  final sentence = sentencesList[index];
                  return ValueListenableBuilder<int?>(
                    valueListenable: _ploc.currentSentenceIndexNotifier, // _ploc is the instance of CourseSentencesOverviewPloc
                    builder: (context, playingIndex, child) {
                      final bool isPlaying = playingIndex == index;
                      return ListTile(
                        title: Text(
                          sentence.english, // Or sentence.chinese, or a combination based on display requirements
                          style: TextStyle(
                            fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                            // Optionally, change text color as well:
                            // color: isPlaying ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.titleMedium?.color,
                          ),
                        ),
                        selected: isPlaying,
                        // Using focusColor for highlighting. Adjust opacity or color as needed for visual clarity.
                        selectedTileColor: Theme.of(context).focusColor.withOpacity(0.3),
                        onTap: () {
                          _ploc.stop(); // Stop audio playback on the current page

                          final sentenceObject = sentencesList[index]; // sentencesList and index from itemBuilder scope

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => LearningPage(
                                title: _courseName ?? widget.courseId.toString(), // Use fetched course name or fallback
                                sentenceSrc: SentenceSource(
                                  type: SentenceSourceType.sentence,
                                  id: sentenceObject.id,
                                  sentences: [sentenceObject],
                                  name: _courseName ?? "Course Sentences", // Contextual name for SentenceSource
                                  parentId: widget.courseId, // ID of the parent course
                                ),
                                // audioLength is optional and can be omitted
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
            logger: _log,
            logId: 'FetchSentencesForOverview',
            onLoadingPlaceholder: const Center(child: CircularProgressIndicator()),
            onErrorPlaceholder: const Center(child: Text('Error loading sentences.')),
          );
        },
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _ploc.isPlayingNotifier,
        builder: (context, isPlaying, child) {
          return FloatingActionButton(
            onPressed: () {
              _ploc.playPause();
            },
            child: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          );
        },
      ),
    );
  }
}
