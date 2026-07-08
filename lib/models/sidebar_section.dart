enum BookSort {
  lastRead('最近阅读'),
  lastAdded('最近添加'),
  author('作者'),
  title('名称'),
  progress('阅读进度'),
  fileSize('文件大小');

  const BookSort(this.label);

  final String label;
}
