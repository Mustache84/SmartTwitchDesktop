import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/multi_stream_state.dart';
import 'video_controller_manager.dart';

/// Grid layout for displaying multiple streams (up to 4) with drag-and-drop reordering
class MultiStreamGrid extends ConsumerStatefulWidget {
  const MultiStreamGrid({super.key});

  @override
  ConsumerState<MultiStreamGrid> createState() => _MultiStreamGridState();
}

class _MultiStreamGridState extends ConsumerState<MultiStreamGrid> {
  int? _draggedSlot;
  int? _hoveredSlot;
  
  @override
  Widget build(BuildContext context) {
    final slots = ref.watch(multiStreamProvider);
    
    // Always show 2x2 grid for consistency with drag-drop
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildDraggableSlot(slots[0])),
              const SizedBox(width: 2),
              Expanded(child: _buildDraggableSlot(slots[1])),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildDraggableSlot(slots[2])),
              const SizedBox(width: 2),
              Expanded(child: _buildDraggableSlot(slots[3])),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildDraggableSlot(StreamSlot slot) {
    final isDragging = _draggedSlot == slot.position;
    final isHovered = _hoveredSlot == slot.position && _draggedSlot != null && _draggedSlot != slot.position;
    
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        setState(() => _hoveredSlot = slot.position);
        return details.data != slot.position;
      },
      onLeave: (_) {
        setState(() => _hoveredSlot = null);
      },
      onAcceptWithDetails: (details) {
        ref.read(multiStreamProvider.notifier).swapSlots(details.data, slot.position);
        setState(() {
          _hoveredSlot = null;
          _draggedSlot = null;
        });
      },
      builder: (context, candidateData, rejectedData) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // The actual slot content (draggable if active)
            if (slot.isActive)
              Draggable<int>(
                data: slot.position,
                onDragStarted: () => setState(() => _draggedSlot = slot.position),
                onDragEnd: (_) => setState(() {
                  _draggedSlot = null;
                  _hoveredSlot = null;
                }),
                feedback: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 200,
                    height: 112,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple, width: 2),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.drag_indicator, color: Colors.white),
                          const SizedBox(height: 4),
                          Text(
                            slot.channelLogin!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                childWhenDragging: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    border: Border.all(color: Colors.purple.withOpacity(0.5), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      slot.channelLogin!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ),
                ),
                child: _buildSlotContent(slot, isDragging: isDragging),
              )
            else
              _buildSlotContent(slot, isDragging: false),
            
            // Drop zone highlight
            if (isHovered)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.purple, width: 3),
                  color: Colors.purple.withOpacity(0.2),
                ),
                child: const Center(
                  child: Icon(Icons.swap_horiz, color: Colors.purple, size: 48),
                ),
              ),
          ],
        );
      },
    );
  }
  
  Widget _buildSlotContent(StreamSlot slot, {required bool isDragging}) {
    if (!slot.isActive) {
      return _EmptySlotPlaceholder(slotIndex: slot.position);
    }
    
    return GestureDetector(
      onTap: () {
        // Toggle audio on tap
        ref.read(multiStreamProvider.notifier).toggleAudio(slot.position);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video player - keyed by channel name only for persistence during drag/drop
          PersistentVideoWidget(
            key: ValueKey(slot.channelLogin),
            channelLogin: slot.channelLogin!,
            hlsUrl: slot.hlsUrl!,
            hasAudio: slot.hasAudio,
          ),
          
          // Drag handle indicator (top-left)
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.drag_indicator,
                color: Colors.white54,
                size: 18,
              ),
            ),
          ),
          
          // Channel name overlay
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                slot.channelLogin!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          
          // Audio indicator
          if (slot.hasAudio)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            )
          else
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.volume_off,
                  color: Colors.white54,
                  size: 20,
                ),
              ),
            ),
          
          // Close button
          Positioned(
            right: 8,
            bottom: 8,
            child: IconButton(
              onPressed: () {
                ref.read(multiStreamProvider.notifier).removeStream(slot.position);
              },
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder widget for empty stream slots
class _EmptySlotPlaceholder extends ConsumerWidget {
  final int slotIndex;
  
  const _EmptySlotPlaceholder({required this.slotIndex});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<int>(
      onAcceptWithDetails: (details) {
        // Move stream to this empty slot
        final slots = ref.read(multiStreamProvider);
        final sourceSlot = slots[details.data];
        if (sourceSlot.isActive) {
          ref.read(multiStreamProvider.notifier).swapSlots(details.data, slotIndex);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        
        return Container(
          decoration: BoxDecoration(
            color: isHovered ? Colors.purple.withOpacity(0.2) : Colors.grey[900],
            border: isHovered ? Border.all(color: Colors.purple, width: 3) : null,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isHovered ? Icons.add_box : Icons.add_circle_outline,
                  size: 48,
                  color: isHovered ? Colors.purple : Colors.grey[600],
                ),
                const SizedBox(height: 8),
                Text(
                  isHovered ? 'Drop here' : 'Slot ${slotIndex + 1}',
                  style: TextStyle(
                    color: isHovered ? Colors.purple : Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
