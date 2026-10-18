enum MediaType {
  image('image'),
  video('video');

  const MediaType(this.firestoreValue);

  final String firestoreValue;

  /// Los documentos anteriores a las fotos no tienen `mediaType`; se leen como
  /// video, igual que antes.
  static MediaType fromFirestore(Object? value) =>
      value == image.firestoreValue ? image : video;
}
