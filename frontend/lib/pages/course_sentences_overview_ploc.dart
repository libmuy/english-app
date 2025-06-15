import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:libmuy_audioplayer/libmuy_audioplayer.dart';
import 'package:muy_english_project/domain/entities.dart';
import 'package:muy_english_project/providers/learning_provider.dart';
import 'package:muy_english_project/providers/service_locator.dart';
import 'package:simple_logging/simple_logging.dart';

final _log = Logger('CourseSentencesOverviewPloc');

class CourseSentencesOverviewPloc {
  final _audioPlayer = LibmuyAudioplayer();
  List<Sentence> _sentences = [];
  int? _currentPlayingIndex;

  final isPlayingNotifier = ValueNotifier<bool>(false);
  final currentSentenceIndexNotifier = ValueNotifier<int?>(null);
  final audioErrorNotifier = ValueNotifier<String?>(null);

  StreamSubscription? _positionSubscription;
  Duration _currentSentenceDuration = Duration.zero;
  bool _isCompletingPlayback = false; // To prevent re-entry in completion handler


  CourseSentencesOverviewPloc() {
    // Using onPositionChanged as per learning_page_ploc.dart
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (_isCompletingPlayback || _currentSentenceDuration == Duration.zero || !isPlayingNotifier.value) {
        // Not playing, no duration, or already handling completion: do nothing.
        return;
      }

      // Check for completion (e.g. position >= duration - small_offset)
      const kStopOffset = Duration(milliseconds: 200); // From learning_page_ploc.dart

      if (position + kStopOffset >= _currentSentenceDuration) {
        _isCompletingPlayback = true;
        _log.debug('Playback completed for sentence index $_currentPlayingIndex');

        // Pause first to stop further position events immediately
        _audioPlayer.pause();
        isPlayingNotifier.value = false;

        if (_currentPlayingIndex != null) {
          if (_currentPlayingIndex! < _sentences.length - 1) {
            _playNextSentence(); // This will set isPlayingNotifier to true again if successful
          } else {
            // Last sentence played
            currentSentenceIndexNotifier.value = null;
            _currentSentenceDuration = Duration.zero;
            // isPlayingNotifier already false
          }
        }
        _isCompletingPlayback = false;
      }
    }, onError: (Object e, StackTrace? st) {
      _log.severe('Error in onPositionChanged stream: $e', st);
      isPlayingNotifier.value = false;
      audioErrorNotifier.value = "Audio playback error.";
    });
  }

  void init(List<Sentence> sentences) {
    _sentences = sentences;
    _currentPlayingIndex = null;
    _currentSentenceDuration = Duration.zero;
    currentSentenceIndexNotifier.value = null;
    if (isPlayingNotifier.value) {
        _audioPlayer.pause();
        isPlayingNotifier.value = false;
    }
    if (_sentences.isEmpty) {
        _log.info("Initialized PLoC with an empty sentence list.");
    }
  }

  Future<void> _loadAndPlay(int index) async {
    if (index < 0 || index >= _sentences.length) {
        _log.warning('Invalid index for _loadAndPlay: $index. Sentences count: ${_sentences.length}');
        audioErrorNotifier.value = "Internal error: Invalid sentence index.";
        stop();
        return;
    }

    _currentPlayingIndex = index;
    currentSentenceIndexNotifier.value = index;
    audioErrorNotifier.value = null;
    _isCompletingPlayback = false;

    try {
      final audioPathKey = _sentences[index].audio;
      if (audioPathKey.isEmpty) {
        _log.warning('Audio path is empty for sentence index $index.');
        audioErrorNotifier.value = "Audio not available for this sentence (no path).";
        isPlayingNotifier.value = false;
        if (_currentPlayingIndex! < _sentences.length - 1) { _playNextSentence(); } else { stop(); }
        return;
      }

      final audioBytes = await getIt<LearningProvider>().fetchAudio(audioPathKey);
      if (audioBytes.isNotEmpty) {
        await _audioPlayer.setSource(audioBytes);
        // ASSUMPTION: LibmuyAudioplayer has a synchronous `duration` getter after setSource.
        // If it's asynchronous or a stream, this needs adjustment.
        _currentSentenceDuration = _audioPlayer.duration ?? Duration.zero;

        if (_currentSentenceDuration == Duration.zero) {
            _log.warning('Loaded audio for sentence $index but duration is zero.');
            // Consider this a failure to load properly for playback.
            audioErrorNotifier.value = "Failed to load audio: Invalid duration.";
            isPlayingNotifier.value = false;
            if (_currentPlayingIndex! < _sentences.length - 1) { _playNextSentence(); } else { stop(); }
            return;
        }
        _audioPlayer.play();
        isPlayingNotifier.value = true;
      } else {
        _log.warning('Fetched audio bytes are null or empty for sentence index $index, audio path: $audioPathKey');
        audioErrorNotifier.value = "Failed to load audio: Data not found.";
        isPlayingNotifier.value = false;
        if (_currentPlayingIndex! < _sentences.length - 1) { _playNextSentence(); } else { stop(); }
      }
    } catch (e, st) {
      _log.severe('Error loading or playing audio for sentence $index (${_sentences[index].audio}): $e', st);
      audioErrorNotifier.value = "Error playing audio. Please try again.";
      isPlayingNotifier.value = false;
      _currentSentenceDuration = Duration.zero;
      if (_currentPlayingIndex != null && _currentPlayingIndex! < _sentences.length - 1) {
           _playNextSentence();
      } else {
           stop();
      }
    }
  }

  void playPause() {
    if (_sentences.isEmpty) {
      _log.info("Play/Pause called but no sentences are loaded.");
      return;
    }

    if (isPlayingNotifier.value) {
      _audioPlayer.pause();
      isPlayingNotifier.value = false;
    } else {
      if (_currentPlayingIndex == null || _currentSentenceDuration == Duration.zero) {
        // No sentence has been played yet, or current one has no duration (e.g., after stop/error)
        _loadAndPlay(0);
      } else {
        // If paused or playback was completed for the current sentence (now handled by onPositionChanged),
        // or if simply wanting to replay the current loaded sentence.
        if (currentSentenceIndexNotifier.value == null &&
            _currentPlayingIndex != null &&
            _currentPlayingIndex == _sentences.length -1 &&
            _currentSentenceDuration == Duration.zero) { // Explicitly stopped at the end of the list
             _loadAndPlay(_currentPlayingIndex!); // Reload and play the last one
        } else if (_currentSentenceDuration != Duration.zero) { // A source is loaded
             _audioPlayer.play();
             isPlayingNotifier.value = true;
        } else { // Fallback: No source loaded or unknown state, reload current
            if (_currentPlayingIndex != null) _loadAndPlay(_currentPlayingIndex!); else _loadAndPlay(0);
        }
      }
    }
  }

  void playSentenceAtIndex(int index) {
    if (index < 0 || index >= _sentences.length) {
        _log.warning("playSentenceAtIndex: Invalid index $index");
        return;
    }
    _loadAndPlay(index);
  }

  void _playNextSentence() {
    if (_currentPlayingIndex != null && _currentPlayingIndex! < _sentences.length - 1) {
      _loadAndPlay(_currentPlayingIndex! + 1);
    } else {
      _log.info("Reached end of playlist, stopping.");
      stop();
    }
  }

  void stop() {
    _audioPlayer.pause();
    // _audioPlayer.seek(Duration.zero); // Optional: reset position to start if desired on stop
    isPlayingNotifier.value = false;
    _currentPlayingIndex = null;
    _currentSentenceDuration = Duration.zero;
    currentSentenceIndexNotifier.value = null;
    audioErrorNotifier.value = null;
  }

  void dispose() {
    _log.debug('Disposing CourseSentencesOverviewPloc');
    _positionSubscription?.cancel();
    _audioPlayer.dispose();
    isPlayingNotifier.dispose();
    currentSentenceIndexNotifier.dispose();
    audioErrorNotifier.dispose();
  }
}
