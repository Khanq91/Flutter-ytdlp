String VNnormalize(String input) {
  const vietnamese = 'àáạảãâầấậẩẫăằắặẳẵ'
      'èéẹẻẽêềếệểễ'
      'ìíịỉĩ'
      'òóọỏõôồốộổỗơờớợởỡ'
      'ùúụủũưừứựửữ'
      'ỳýỵỷỹ'
      'đ'
      'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ'
      'ÈÉẸẺẼÊỀẾỆỂỄ'
      'ÌÍỊỈĨ'
      'ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ'
      'ÙÚỤỦŨƯỪỨỰỬỮ'
      'ỲÝỴỶỸ'
      'Đ';

  const nonVietnamese = 'aaaaaaaaaaaaaaaaa'
      'eeeeeeeeeee'
      'iiiii'
      'ooooooooooooooooo'
      'uuuuuuuuuuu'
      'yyyyy'
      'd'
      'AAAAAAAAAAAAAAAAA'
      'EEEEEEEEEEE'
      'IIIII'
      'OOOOOOOOOOOOOOOOO'
      'UUUUUUUUUUU'
      'YYYYY'
      'D';

  var result = input;

  for (int i = 0; i < vietnamese.length; i++) {
    result = result.replaceAll(vietnamese[i], nonVietnamese[i]);
  }

  return result.toLowerCase();
}