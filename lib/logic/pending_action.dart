enum PendingType {
  islandReaction,
  mountainTarget,
  scryOne,
  blackmail,
  regrowth,
}

class PendingAction {
  final PendingType type;
  final dynamic data;
  PendingAction(this.type, [this.data]);
}