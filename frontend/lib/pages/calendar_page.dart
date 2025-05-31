import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/learning_provider.dart';
// import '../domain/global.dart'; // For kDefaultSettings etc., if needed for styling
import '../theme.dart'; // For app theme colors

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  static const routeName = '/calendar';

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late LearningProvider _learningProvider;
  Map<DateTime, List<DailySummary>> _events = {};
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _learningProvider = Provider.of<LearningProvider>(context, listen: false);
    _fetchLearningSummary();
  }

  Future<void> _fetchLearningSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final summaries = await _learningProvider.fetchDailyLearningSummary();
      final Map<DateTime, List<DailySummary>> eventsMap = {};
      for (var summary in summaries) {
        // Normalize to UTC to avoid timezone issues with date comparisons
        final dateKey = DateTime.utc(summary.date.year, summary.date.month, summary.date.day);
        if (eventsMap[dateKey] == null) {
          eventsMap[dateKey] = [];
        }
        eventsMap[dateKey]!.add(summary);
      }
      setState(() {
        _events = eventsMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Failed to load learning summary: ${e.toString()}";
      });
    }
  }

  List<DailySummary> _getEventsForDay(DateTime day) {
    // Normalize day to UTC for lookup
    final dateKey = DateTime.utc(day.year, day.month, day.day);
    return _events[dateKey] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Calendar'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    TableCalendar<DailySummary>(
                      firstDay: DateTime.utc(2024, 1, 1), // Adjust as needed
                      lastDay: DateTime.utc(DateTime.now().year + 1, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (day) {
                        return isSameDay(_selectedDay, day);
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                        if (!isSameDay(_selectedDay, selectedDay)) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        }
                      },
                      onFormatChanged: (format) {
                        if (_calendarFormat != format) {
                          setState(() {
                            _calendarFormat = format;
                          });
                        }
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },
                      eventLoader: _getEventsForDay,
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          if (events.isNotEmpty) {
                            return Positioned(
                              right: 1,
                              bottom: 1,
                              child: Container(
                                padding: const EdgeInsets.all(2.0),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                                child: Text(
                                  '${events.fold<int>(0, (sum, item) => sum + item.sentenceCount)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                ),
                              ),
                            );
                          }
                          return null;
                        },
                      ),
                      calendarStyle: CalendarStyle(
                         todayDecoration: BoxDecoration(
                             color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
                             shape: BoxShape.circle,
                         ),
                         selectedDecoration: BoxDecoration(
                             color: Theme.of(context).primaryColor,
                             shape: BoxShape.circle,
                         ),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Expanded(
                      child: _selectedDay != null
                          ? ListView(
                              children: _getEventsForDay(_selectedDay!)
                                  .map((summary) => ListTile(
                                        title: Text('Sentences Learned: ${summary.sentenceCount}'),
                                        subtitle: Text('Date: ${summary.date.toLocal().toString().split(' ')[0]}'),
                                      ))
                                  .toList(),
                            )
                          : const Center(child: Text('Select a day to see details')),
                    ),
                  ],
                ),
    );
  }
}
