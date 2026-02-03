import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/video_controller_manager.dart';

/// Represents a single stream slot in the multi-view layout
class StreamSlot {
  final int position;        // 0-3 for quad layout
  final String? channelLogin;
  final String? hlsUrl;
  final bool hasAudio;
  final DateTime? watchingSince;
  
  const StreamSlot({
    required this.position,
    this.channelLogin,
    this.hlsUrl,
    this.hasAudio = false,
    this.watchingSince,
  });
  
  StreamSlot copyWith({
    int? position,
    String? channelLogin,
    String? hlsUrl,
    bool? hasAudio,
    DateTime? watchingSince,
  }) {
    return StreamSlot(
      position: position ?? this.position,
      channelLogin: channelLogin ?? this.channelLogin,
      hlsUrl: hlsUrl ?? this.hlsUrl,
      hasAudio: hasAudio ?? this.hasAudio,
      watchingSince: watchingSince ?? this.watchingSince,
    );
  }
  
  /// Create an empty slot
  StreamSlot cleared() {
    return StreamSlot(position: position);
  }
  
  bool get isEmpty => channelLogin == null;
  bool get isActive => channelLogin != null && hlsUrl != null;
}

/// Notifier for managing multiple stream slots (Riverpod v3)
class MultiStreamNotifier extends Notifier<List<StreamSlot>> {
  static const maxSlots = 4;
  
  @override
  List<StreamSlot> build() {
    return List.generate(maxSlots, (i) => StreamSlot(position: i));
  }
  
  /// Add a stream to the first available slot
  /// Returns the slot index, or -1 if no slots available
  int addStream(String channelLogin, String hlsUrl) {
    final emptyIndex = firstEmptySlot;
    if (emptyIndex == null) return -1;
    
    final newState = [...state];
    newState[emptyIndex] = StreamSlot(
      position: emptyIndex,
      channelLogin: channelLogin,
      hlsUrl: hlsUrl,
      hasAudio: activeStreamCount == 0, // First stream gets audio
      watchingSince: DateTime.now(),
    );
    state = newState;
    
    print('[MultiStream] Added $channelLogin to slot $emptyIndex');
    return emptyIndex;
  }
  
  /// Add a stream to a specific slot
  void addStreamToSlot(int slotIndex, String channelLogin, String hlsUrl) {
    if (slotIndex < 0 || slotIndex >= maxSlots) return;
    
    final newState = [...state];
    newState[slotIndex] = StreamSlot(
      position: slotIndex,
      channelLogin: channelLogin,
      hlsUrl: hlsUrl,
      hasAudio: activeStreamCount == 0 || state[slotIndex].hasAudio,
      watchingSince: DateTime.now(),
    );
    state = newState;
    
    print('[MultiStream] Added $channelLogin to slot $slotIndex');
  }
  
  /// Remove a stream from a slot
  void removeStream(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= maxSlots) return;
    
    final channelLogin = state[slotIndex].channelLogin;
    final wasAudioSlot = state[slotIndex].hasAudio;
    final newState = [...state];
    newState[slotIndex] = state[slotIndex].cleared();
    state = newState;
    
    // Dispose the video controller for the removed stream
    if (channelLogin != null) {
      VideoControllerManager().disposeController(channelLogin);
    }
    
    // If removed stream had audio, give it to first active stream
    if (wasAudioSlot) {
      final firstActive = state.indexWhere((s) => s.isActive);
      if (firstActive != -1) {
        setAudioFocus(firstActive);
      }
    }
    
    print('[MultiStream] Removed stream from slot $slotIndex');
  }
  
  /// Set which slot has audio focus (only one at a time)
  void setAudioFocus(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= maxSlots) return;
    if (!state[slotIndex].isActive) return;
    
    state = [
      for (int i = 0; i < maxSlots; i++)
        state[i].copyWith(hasAudio: i == slotIndex),
    ];
    
    print('[MultiStream] Audio focus set to slot $slotIndex');
  }
  
  /// Toggle audio on a slot (mute all if clicking the active audio slot)
  void toggleAudio(int slotIndex) {
    if (!state[slotIndex].isActive) return;
    
    if (state[slotIndex].hasAudio) {
      // Already has audio - mute all
      state = [
        for (final slot in state)
          slot.copyWith(hasAudio: false),
      ];
    } else {
      // Give audio to this slot
      setAudioFocus(slotIndex);
    }
  }
  
  /// Rotate stream positions (for reordering)
  void rotatePositions() {
    if (activeStreamCount < 2) return;
    
    // Rotate clockwise: 0->1->3->2->0
    final rotationOrder = [1, 3, 2, 0];
    final newState = List<StreamSlot>.filled(maxSlots, const StreamSlot(position: 0));
    
    for (int i = 0; i < maxSlots; i++) {
      final targetPosition = rotationOrder[i];
      newState[targetPosition] = state[i].copyWith(position: targetPosition);
    }
    
    state = newState;
    print('[MultiStream] Rotated positions');
  }
  
  /// Swap two slots
  void swapSlots(int slotA, int slotB) {
    if (slotA < 0 || slotA >= maxSlots) return;
    if (slotB < 0 || slotB >= maxSlots) return;
    if (slotA == slotB) return;
    
    final newState = [...state];
    newState[slotA] = state[slotB].copyWith(position: slotA);
    newState[slotB] = state[slotA].copyWith(position: slotB);
    state = newState;
    
    print('[MultiStream] Swapped slots $slotA and $slotB');
  }
  
  /// Clear all streams
  void clearAll() {
    state = List.generate(maxSlots, (i) => StreamSlot(position: i));
    print('[MultiStream] Cleared all streams');
  }
  
  /// Get the first empty slot index
  int? get firstEmptySlot {
    for (int i = 0; i < maxSlots; i++) {
      if (state[i].isEmpty) return i;
    }
    return null;
  }
  
  /// Check if all slots are full
  bool get isFull => firstEmptySlot == null;
  
  /// Count of active streams
  int get activeStreamCount => state.where((s) => s.isActive).length;
  
  /// Get the slot with audio
  int? get audioSlotIndex {
    for (int i = 0; i < maxSlots; i++) {
      if (state[i].hasAudio) return i;
    }
    return null;
  }
}

/// Provider for multi-stream state (Riverpod v3)
final multiStreamProvider = NotifierProvider<MultiStreamNotifier, List<StreamSlot>>(
  MultiStreamNotifier.new,
);
