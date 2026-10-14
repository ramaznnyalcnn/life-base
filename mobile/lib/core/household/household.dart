/// Everything is shared by the household; each item says who added it and
/// whose phone reminds about it.
library;

/// Both phones remind.
const notifyAll = 'all';

/// Whether this phone ([me], a user id; 0 while unknown) reminds about an
/// item aimed at [notify]. Unknown means remind: a missed alarm is worse.
bool remindsMe(String notify, int me) => notify == notifyAll || me == 0 || notify == '$me';

/// The [items] this phone reminds about.
List<T> remindedHere<T>(Iterable<T> items, String Function(T item) notifyOf, int me) =>
    [for (final item in items) if (remindsMe(notifyOf(item), me)) item];
