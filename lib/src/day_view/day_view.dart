import 'package:flutter/material.dart';
import 'package:flutter_calendar_page/src/calendar_controller.dart';
import 'package:flutter_calendar_page/src/components/day_view_components.dart';
import 'package:flutter_calendar_page/src/constants.dart';
import 'package:flutter_calendar_page/src/extensions.dart';

import '../event_arrangers/event_arrangers.dart';
import '../modals.dart';
import '_internal_day_view_page.dart';

class DayView<T> extends StatefulWidget {
  /// A function that returns a [Widget] that determines appearance of each cell in day calendar.
  ///
  final EventTileBuilder<T>? eventTileBuilder;

  /// A function that returns a [Widget] that will be displayed left side of day view.
  ///
  /// If null is provided then no time line will be visible.
  ///
  final DateWidgetBuilder? timeLineBuilder;

  /// Builds day title bar.
  ///
  final DateWidgetBuilder? dayTitleBuilder;

  /// Defines how events are arranged in day view.
  /// User can define custom event arranger by implementing [EventArranger] class
  /// and pass object of that class as argument.
  ///
  final EventArranger<T>? eventArranger;

  /// This callback will run whenever page will change.
  ///
  final CalendarPageChangeCallBack? onPageChange;

  /// Determines the lower boundary user can scroll.
  ///
  /// If not provided [Constants.epochDate] is default.
  ///
  final DateTime? minDay;

  /// Determines upper boundary user can scroll.
  ///
  /// If not provided [Constants.maxDate] is default.
  ///
  final DateTime? maxDay;

  /// Defines initial display day.
  ///
  /// If not provided current date is default date.
  ///
  final DateTime? initialDay;

  /// Defines settings for hour indication lines.
  ///
  /// If null or [HourIndicatorSettings.none()] provided no lines will be displayed or provide to remove lines.
  ///
  final HourIndicatorSettings? hourIndicatorSettings;

  /// Defines settings for live time indicator.
  ///
  /// If null or [HourIndicatorSettings.none()] provided no lines will be displayed or provide to remove lines.
  ///
  final HourIndicatorSettings? liveTimeIndicatorSettings;

  /// Page transition duration used when user try to change page using [DayView.nextPage] or [DayView.previousPage]
  ///
  final Duration pageTransitionDuration;

  /// Page transition curve used when user try to change page using [DayView.nextPage] or [DayView.previousPage]
  ///
  final Curve pageTransitionCurve;

  /// A required parameters that controls events for day view.
  ///
  /// This will auto update day view when user adds events in controller.
  /// This controller will store all the events. And returns events for particular day.
  ///
  final CalendarController<T> controller;

  /// Defines aspect ratio of day cells in day calendar page.
  ///
  final double heightPerMinute;

  /// Defines the width of timeline.
  ///
  final double? timeLineWidth;

  /// if parsed true then live time line will be displayed in all days.
  /// else it will be displayed in [DateTime.now] only.
  ///
  /// Parse [HourIndicatorSettings.none()] as argument in [DayView.liveTimeIndicatorSettings]
  /// to remove time line completely.
  ///
  final bool showLiveTimeLineInAllDays;

  /// Defines offset for timeline.
  ///
  /// This will translate all the widgets returned by [DayView.timeLineBuilder] by provided offset.
  ///
  /// If offset is positive all the widgets will be translated up.
  ///
  /// If offset is negative all the widgets will be translated down.
  ///
  final double timeLineOffset;

  /// Width of day page.
  ///
  /// if null provided then device width will be considered.
  ///
  final double? width;

  /// If true this will display vertical line in day view.
  final bool showVerticalLine;

  /// Defines offset of vertical line from hour line starts.
  final double verticalLineOffset;

  /// Main widget for day view.
  const DayView({
    Key? key,
    required this.eventTileBuilder,
    required this.controller,
    this.showVerticalLine = true,
    this.pageTransitionDuration = const Duration(milliseconds: 300),
    this.pageTransitionCurve = Curves.ease,
    this.width,
    this.minDay,
    this.maxDay,
    this.initialDay,
    this.hourIndicatorSettings,
    this.heightPerMinute = 1,
    this.timeLineBuilder,
    this.timeLineWidth,
    this.timeLineOffset = 0,
    this.showLiveTimeLineInAllDays = false,
    this.liveTimeIndicatorSettings,
    this.onPageChange,
    this.dayTitleBuilder,
    this.eventArranger,
    this.verticalLineOffset = 10,
  })  : assert((timeLineOffset) >= 0,
            "timeLineOffset must be greater than or equal to 0"),
        super(key: key);

  @override
  DayViewState<T> createState() => DayViewState<T>();
}

class DayViewState<T> extends State<DayView<T>> {
  late double _width;
  late double _height;
  late double _timeLineWidth;
  late double _hourHeight;
  late double _timeLineOffset;
  late DateTime _currentDate;
  late DateTime _maxDate;
  late DateTime _minDate;
  late DateTime _initialDay;
  late int _totalDays;
  late int _currentIndex;

  late EventArranger<T> _eventArranger;

  late HourIndicatorSettings _hourIndicatorSettings;
  late HourIndicatorSettings _liveTimeIndicatorSettings;

  late PageController _pageController;

  late DateWidgetBuilder _timeLineBuilder;

  late EventTileBuilder<T> _eventTileBuilder;

  late DateWidgetBuilder _dayTitleBuilder;

  @override
  void initState() {
    super.initState();

    _minDate = widget.minDay ?? Constants.epochDate;
    _maxDate = widget.maxDay ?? Constants.maxDate;

    _initialDay = widget.initialDay ?? DateTime.now();

    if (_initialDay.isBefore(_minDate)) {
      _initialDay = _minDate;
    } else if (_initialDay.isAfter(_maxDate)) {
      _initialDay = _maxDate;
    }
    _currentDate = _initialDay;
    _totalDays = _maxDate.getDayDifference(_minDate) + 1;
    widget.controller.addListener(_reload);
    _currentIndex = _currentDate.getDayDifference(_minDate);
    _hourHeight = widget.heightPerMinute * 60;
    _height = _hourHeight * Constants.hoursADay;
    _timeLineOffset = widget.timeLineOffset;
    _pageController = PageController(initialPage: _currentIndex);
    _eventArranger = widget.eventArranger ?? SideEventArranger<T>();
    _timeLineBuilder = widget.timeLineBuilder ?? _defaultTimeLineBuilder;
    _eventTileBuilder = widget.eventTileBuilder ?? _defaultEventTileBuilder;
    _dayTitleBuilder = widget.dayTitleBuilder ?? _defaultDayBuilder;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _width = widget.width ?? MediaQuery.of(context).size.width;
    assert(_width != 0, "Calendar width can not be 0.");

    _timeLineWidth = widget.timeLineWidth ?? _width * 0.13;
    assert(_timeLineWidth != 0, "Time line width can not be 0.");

    _liveTimeIndicatorSettings = widget.liveTimeIndicatorSettings ??
        HourIndicatorSettings(
          color: Theme.of(context).errorColor,
          height: widget.heightPerMinute,
          offset: 5 + widget.verticalLineOffset,
        );

    assert(_liveTimeIndicatorSettings.height < _hourHeight,
        "liveTimeIndicator height must be less than minuteHeight * 60");

    _hourIndicatorSettings = widget.hourIndicatorSettings ??
        HourIndicatorSettings(
          height: widget.heightPerMinute,
          color: Theme.of(context).primaryColor,
          offset: 5,
        );

    assert(_hourIndicatorSettings.height < _hourHeight,
        "hourIndicator height must be less than minuteHeight * 60");
  }

  @override
  void dispose() {
    widget.controller.removeListener(_reload);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _dayTitleBuilder(_currentDate),
          Expanded(
            child: SingleChildScrollView(
              child: SizedBox(
                height: _height,
                width: _width,
                child: PageView.builder(
                  itemCount: _totalDays,
                  controller: _pageController,
                  onPageChanged: _onPageChange,
                  itemBuilder: (_, index) {
                    DateTime date = DateTime(
                        _minDate.year, _minDate.month, _minDate.day + index);

                    return InternalDayViewPage<T>(
                      key: ValueKey(_hourHeight.toString() + date.toString()),
                      width: _width,
                      liveTimeIndicatorSettings: _liveTimeIndicatorSettings,
                      timeLineBuilder: _timeLineBuilder,
                      eventTileBuilder: _eventTileBuilder,
                      heightPerMinute: widget.heightPerMinute,
                      hourIndicatorSettings: _hourIndicatorSettings,
                      date: date,
                      showLiveLine: widget.showLiveTimeLineInAllDays ||
                          date.compareWithoutTime(DateTime.now()),
                      timeLineOffset: _timeLineOffset,
                      timeLineWidth: _timeLineWidth,
                      verticalLineOffset: widget.verticalLineOffset,
                      showVerticalLine: widget.showVerticalLine,
                      height: _height,
                      controller: widget.controller,
                      hourHeight: _hourHeight,
                      eventArranger: _eventArranger,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Reloads page.
  ///
  void _reload() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Default timeline builder this builder will be used if [widget.eventTileBuilder] is null
  ///
  Widget _defaultTimeLineBuilder(date) => Transform.translate(
        offset: Offset(0, -7.5),
        child: Padding(
          padding: const EdgeInsets.only(right: 7.0),
          child: Text(
            "${((date.hour - 1) % 12) + 1} ${date.hour ~/ 12 == 0 ? "am" : "pm"}",
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15.0,
            ),
          ),
        ),
      );

  /// Default timeline builder. This builder will be used if [widget.eventTileBuilder] is null
  ///
  Widget _defaultEventTileBuilder(
      date, events, boundary, startDuration, endDuration) {
    if (events.isNotEmpty)
      return RoundedEventTile(
        title: events[0].title,
        description: events[0].description,
      );
    else
      return Container();
  }

  /// Default view header builder. This builder will be used if [widget.dayTitleBuilder] is null.
  ///
  Widget _defaultDayBuilder(DateTime date) {
    return DayPageHeader(
      date: _currentDate,
      onNextDay: nextPage,
      onPreviousDay: previousPage,
      onTitleTapped: () async {
        DateTime? selectedDate = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: Constants.minDate,
          lastDate: Constants.maxDate,
        );

        if (selectedDate == null) return;
        this.jumpToDate(selectedDate);
      },
    );
  }

  /// Called when user change page using any gesture or inbuilt functions.
  ///
  void _onPageChange(int index) {
    if (mounted) {
      setState(() {
        _currentDate = DateTime(
          _currentDate.year,
          _currentDate.month,
          _currentDate.day + (index - _currentIndex),
        );
        _currentIndex = index;
      });
    }
    widget.onPageChange?.call(_currentDate, _currentIndex);
  }

  /// Animate to next page
  ///
  /// Arguments [duration] and [curve] will override default values provided
  /// as [DayView.pageTransitionDuration] and [DayView.pageTransitionCurve] respectively.
  ///
  ///
  void nextPage({Duration? duration, Curve? curve}) => _pageController.nextPage(
        duration: duration ?? widget.pageTransitionDuration,
        curve: curve ?? widget.pageTransitionCurve,
      );

  /// Animate to previous page
  ///
  /// Arguments [duration] and [curve] will override default values provided
  /// as [DayView.pageTransitionDuration] and [DayView.pageTransitionCurve] respectively.
  ///
  ///
  void previousPage({Duration? duration, Curve? curve}) =>
      _pageController.previousPage(
        duration: duration ?? widget.pageTransitionDuration,
        curve: curve ?? widget.pageTransitionCurve,
      );

  /// Jumps to page number [page]
  ///
  ///
  void jumpToPage(int page) => _pageController.jumpToPage(page);

  /// Animate to page number [page].
  ///
  /// Arguments [duration] and [curve] will override default values provided
  /// as [DayView.pageTransitionDuration] and [DayView.pageTransitionCurve] respectively.
  ///
  ///
  Future<void> animateToPage(int page,
          {Duration? duration, Curve? curve}) async =>
      await _pageController.animateToPage(page,
          duration: duration ?? widget.pageTransitionDuration,
          curve: curve ?? widget.pageTransitionCurve);

  /// Returns current page number.
  ///
  ///
  int get currentPage => _currentIndex;

  /// Jumps to page which gives day calendar for [date]
  ///
  ///
  void jumpToDate(DateTime date) {
    if (date.isBefore(_minDate) || date.isAfter(_maxDate)) {
      throw "Invalid date selected.";
    }
    _pageController.jumpToPage(_minDate.getDayDifference(date));
  }

  /// Animate to page which gives day calendar for [date].
  ///
  /// Arguments [duration] and [curve] will override default values provided
  /// as [DayView.pageTransitionDuration] and [DayView.pageTransitionCurve] respectively.
  ///
  ///
  Future<void> animateToDate(DateTime date,
      {Duration? duration, Curve? curve}) async {
    if (date.isBefore(_minDate) || date.isAfter(_maxDate)) {
      throw "Invalid date selected.";
    }
    await _pageController.animateToPage(
      _minDate.getDayDifference(date),
      duration: duration ?? widget.pageTransitionDuration,
      curve: curve ?? widget.pageTransitionCurve,
    );
  }

  /// Returns the current visible date in day view.
  DateTime get currentDate =>
      DateTime(_currentDate.year, _currentDate.month, _currentDate.day);
}