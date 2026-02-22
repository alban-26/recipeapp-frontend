import 'package:bloc/bloc.dart';

class BottomNavBarCubit extends Cubit<int> {
  BottomNavBarCubit() : super(0);

  void selectTab(int index) => emit(index);
}
