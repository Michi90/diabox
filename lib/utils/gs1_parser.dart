class Gs1Parser {
  static String? extractLotNumber(String gs1Barcode) {
    // Regular expression for the Lot Number (AI '10')
    // It looks for '10' followed by a group of characters that are not another two-digit AI.
    // The pattern stops at the next AI or the end of the string.
    // '(?=\d{2})' is a positive lookahead to find the next two digits without including them in the match.
    final String gs = String.fromCharCode(29);
    final RegExp regExp = RegExp('(^|$gs)10([^$gs]+)');


    final Match? match = regExp.firstMatch(gs1Barcode);

    if (match != null && match.groupCount >= 2) {
      return match.group(2);



      }

    return null;
  }
}