import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:muy_english_project/domain/entities.dart';
import 'package:muy_english_project/providers/learning_provider.dart';
import 'package:muy_english_project/providers/service_locator.dart';
import 'package:simple_logging/simple_logging.dart';

final _log = Logger('CourseSentencesOverviewPloc');

class CourseSentencesOverviewPloc {
  final _audioPlayer = AudioPlayer();
  List<Sentence> _sentences = [];
  int? _currentPlayingIndex;

  final isPlayingNotifier = ValueNotifier<bool>(false);
  final currentSentenceIndexNotifier = ValueNotifier<int?>(null);
  final audioErrorNotifier = ValueNotifier<String?>(null);

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _playbackEventSubscription;

  CourseSentencesOverviewPloc() {
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      isPlayingNotifier.value = state.playing;
      if (state.processingState == ProcessingState.completed) {
        if (_currentPlayingIndex != null) { // If something was playing
          if (_currentPlayingIndex! < _sentences.length - 1) {
            _playNextSentence();
          } else {
            _audioPlayer.stop();
            currentSentenceIndexNotifier.value = null;
          }
        }
      }
    }, onError: (Object e, StackTrace? st) {
        _log.severe('Error in playerStateStream: $e', st);
    });

    _playbackEventSubscription = _audioPlayer.playbackEventStream.listen((event) {
       // _log.debug('Playback event: $event'); // Can be noisy
    }, onError: (Object e, StackTrace? st) {
      _log.severe('Error in playbackEventStream: $e', st);
    });
  }

  void init(List<Sentence> sentences) {
    _sentences = sentences;
    _currentPlayingIndex = null;
    currentSentenceIndexNotifier.value = null;
    if (_audioPlayer.playing || _audioPlayer.processingState != ProcessingState.idle) {
        _audioPlayer.stop();
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
    audioErrorNotifier.value = null; // Clear previous error for the new attempt

    try {
      final audioPath = _sentences[index].audio;
      if (audioPath.isEmpty) {
        _log.warning('Audio path is empty for sentence index $index.');
        audioErrorNotifier.value = "Audio not available for this sentence (no path).";
        if (_currentPlayingIndex! < _sentences.length - 1) { _playNextSentence(); } else { stop(); }
        return;
      }

      final audioUrl = await getIt<LearningProvider>().getAudioUrl(audioPath);
      if (audioUrl.isNotEmpty) {
        await _audioPlayer.setUrl(audioUrl);
        _audioPlayer.play();
        // audioErrorNotifier.value remains null if successful
      } else {
        _log.warning('Audio URL is null or empty for sentence index $index, audio path: $audioPath');
        audioErrorNotifier.value = "Failed to load audio: URL not found.";
        if (_currentPlayingIndex! < _sentences.length - 1) { _playNextSentence(); } else { stop(); }
      }
    } catch (e, st) {
      _log.severe('Error loading or playing audio for sentence $index (${_sentences[index].audio}): $e', st);
      audioErrorNotifier.value = "Error playing audio. Please try again."; // Generic message for user
      // Log the detailed error: e.toString()
      if (_currentPlayingIndex != null && _currentPlayingIndex! < _sentences.length - 1) {
           _playNextSentence();
      } else {
           stop(); // Stop if it's the last one or standalone error
      }
    }
  }

  void playPause() {
    if (_sentences.isEmpty) {
      _log.info("Play/Pause called but no sentences are loaded.");
      return;
    }

    if (_audioPlayer.playing) {
      _audioPlayer.pause();
    } else {
      if (_currentPlayingIndex == null) {
        _loadAndPlay(0);
      } else {
        if (_audioPlayer.processingState == ProcessingState.completed) {
           _loadAndPlay(_currentPlayingIndex!); // Replay current
        } else if (_audioPlayer.processingState == ProcessingState.ready ||
                   (_audioPlayer.processingState == ProcessingState.idle && _audioPlayer.audioSource != null)) {
          // If paused or idle but source is set, just play
          _audioPlayer.play();
        } else { // Idle and no source, or other indeterminate states
             _loadAndPlay(_currentPlayingIndex!); // Reload current sentence
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
    _audioPlayer.stop();
    _currentPlayingIndex = null;
    currentSentenceIndexNotifier.value = null;
    audioErrorNotifier.value = null; // Clear error on explicit stop
  }

  void dispose() {
    _log.debug('Disposing CourseSentencesOverviewPloc');
    _playerStateSubscription?.cancel();
    _playbackEventSubscription?.cancel();
    _audioPlayer.dispose();
    isPlayingNotifier.dispose();
    currentSentenceIndexNotifier.dispose();
    audioErrorNotifier.dispose(); // Add this line
  }
}
