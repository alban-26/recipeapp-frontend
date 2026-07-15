import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:numberpicker/numberpicker.dart';

import '../../StorageRepository.dart';
import '../../common/form_submission_status.dart';
import '../../shopping/domain/Unit.dart';
import '../../widgets/CommonAppBar.dart';
import '../RecipeRepository.dart';
import '../domain/CookingInstruction.dart';
import '../domain/Recipe.dart';
import '../navigation/RecipeNavigatorCubit.dart';
import 'CreateRecipeBloc.dart';
import 'CreateRecipeEvent.dart';
import 'CreateRecipeState.dart';
import 'package:http/http.dart' as http;


class _ModernLoadingIndicator extends StatelessWidget {
  const _ModernLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(
          strokeWidth: 3,
        ),
        const SizedBox(height: 16),
        Text(
          "Rezept wird analysiert...",
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class CreateRecipeScreen extends StatefulWidget {
  final Recipe recipe;

  const CreateRecipeScreen({super.key, required this.recipe});

  @override
  _CreateRecipeScreenState createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends State<CreateRecipeScreen> {

  late final CreateRecipeBloc _bloc;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bloc = CreateRecipeBloc(
      dataRepo: context.read<RecipeRepository>(),
      storageRepo: context.read<StorageRepository>(),
      recipeNavigatorCubit: context.read<RecipeNavigatorCubit>(),
      initialRecipe: widget.recipe,
    );
  }

  @override
  void dispose() {
    _bloc.close();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocListener<CreateRecipeBloc, CreateRecipeState>(
        listener: (context, state) {
          if (_nameController.text != state.recipe.name) {
            _nameController.value = TextEditingValue(
              text: state.recipe.name,
              selection: TextSelection.collapsed(
                offset: state.recipe.name.length,
              ),
            );
          }
          if (state.imageSourceActionSheetIsVisible) {
            _showImageSourceActionSheet(context);
          }

          if (state.formStatus is SubmissionSuccess) {
            context.read<RecipeNavigatorCubit>().showRecipeDetail(state.recipe);
          }

          if (state.formStatus is SubmissionFailed) {
            final error = (state.formStatus as SubmissionFailed).exception;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error.toString())),
            );
          }
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: CommonAppBar(
            title: 'Rezept erstellen',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.document_scanner_outlined),
                tooltip: 'Rezept scannen',
                onPressed: _scanRecipe,
              ),
            ],
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                child: _createRecipePage(context, _nameController),
              ),

              BlocBuilder<CreateRecipeBloc, CreateRecipeState>(
                builder: (context, state) {
                  if (!state.isScanning) return const SizedBox.shrink();

                  return Container(
                    color: Colors.black.withOpacity(0.4),
                    child: const Center(
                      child: _ModernLoadingIndicator(),
                    ),
                  );
                },
              ),
            ],
          ),

        ),
      ),
    );
  }




  Future<void> _scanRecipe() async {
    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 60,
      maxWidth: 1280,
      maxHeight: 1280,
    );

    if (image == null) return;

    // 👉 START LOADING
    _bloc.add(ScanRecipeStarted());

    final request = http.MultipartRequest(
      "POST",
      Uri.parse("https://loveyourmeal.cloud/api/v1/recipes/extract"),
    );

    request.files.add(
      await http.MultipartFile.fromPath("file", image.path),
    );

    try {
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception("OCR Fehler: ${response.statusCode}");
      }

      final body = await response.stream.bytesToString();
      final json = jsonDecode(body);

      _bloc.add(RecipeScanned(json));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Scan fehlgeschlagen: $e")),
      );
    } finally {
      // 👉 STOP LOADING
      _bloc.add(ScanRecipeFinished());
    }
  }

}

Widget _createRecipePage(BuildContext buildContext, TextEditingController nameController) {
  return BlocBuilder<CreateRecipeBloc, CreateRecipeState>(
    builder: (context, state) {
      return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: _recipePictureWithOverlay(context)),
            const SizedBox(height: 20),
            _nameField(context, nameController),
            Center(child: _portionsAndDuration()),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Zutaten', style: TextStyle(fontSize: 17.0)),
            ),
            ..._buildIngredientFields(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Schritte', style: TextStyle(fontSize: 17.0)),
            ),
            ..._buildDescriptionFields(),
            _saveCreateRecipeChangesButton(),
          ],
        ),
      );
    },
  );
}

Widget _recipePictureWithOverlay(BuildContext context) {
  return BlocBuilder<CreateRecipeBloc, CreateRecipeState>(
    builder: (context, state) {
      final width = MediaQuery.of(context).size.width * 0.7;
      final height = width;

      if (state.recipe.image == null) {
        return GestureDetector(
          onTap: () => context.read<CreateRecipeBloc>().add(ChangeRecipeImageRequest()),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Icon(Icons.add_a_photo, size: width * 0.25, color: Colors.grey.shade600),
          ),
        );
      } else {
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: Image.memory(
                state.recipe.image!,
                width: width,
                height: height,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Material(
                color: Colors.black.withOpacity(0.5),
                shape: const CircleBorder(),
                elevation: 4,
                child: IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  onPressed: () => context.read<CreateRecipeBloc>().add(ChangeRecipeImageRequest()),
                ),
              ),
            ),
          ],
        );
      }
    },
  );
}

// -------------------- Name Field --------------------

Widget _nameField(BuildContext context, TextEditingController nameController) {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: TextFormField(
      controller: nameController,
      decoration: InputDecoration(
        hintText: 'Rezept Name',
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
      ),
      onChanged: (value) {
        context.read<CreateRecipeBloc>().add(
          RecipeNameChanged(recipeName: value),
        );
      },
    ),
  );
}

Widget _portionsAndDuration() {
  return BlocBuilder<CreateRecipeBloc, CreateRecipeState>(
    builder: (context, state) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FontAwesomeIcons.bowlRice, size: 30),
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, color: Colors.grey.shade600, size: 30),
                  onPressed: () {
                    if (state.recipe.portions > 1) {
                      context.read<CreateRecipeBloc>().add(DecrementPortions());
                    }
                  },
                ),
                Text('${state.recipe.portions}', style: TextStyle(fontSize: 16.0, color: Theme.of(context).primaryColor)),
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: Colors.grey.shade600, size: 30),
                  onPressed: () {
                    context.read<CreateRecipeBloc>().add(IncrementPortions());
                  },
                ),
                const SizedBox(width: 20),
                const Icon(Icons.access_time_rounded, size: 30),
                const SizedBox(width: 8),
                _buildNumberPicker(),
              ],
            ),
          ),
        ),
      );
    },
  );
}

String customTextMapper(String numberText) => '$numberText min';

Widget _buildNumberPicker() {
  return BlocBuilder<CreateRecipeBloc, CreateRecipeState>(
    builder: (context, state) {
      return NumberPicker(
        selectedTextStyle: TextStyle(fontSize: 16.0, color: Theme.of(context).primaryColor),
        itemHeight: 22,
        itemWidth: 70,
        step: 5,
        minValue: 0,
        maxValue: 240,
        value: state.recipe.duration.inMinutes,
        onChanged: (value) => context.read<CreateRecipeBloc>().add(DurationChanged(duration: value)),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade600, width: 1.5),
          borderRadius: BorderRadius.circular(6.0),
        ),
        textMapper: customTextMapper,
      );
    },
  );
}

// -------------------- Ingredients --------------------

List<Widget> _buildIngredientFields() {
  const double fieldHeight = 48.0;
  final List<Unit> units = Unit.values;


  return [
    BlocBuilder<CreateRecipeBloc, CreateRecipeState>(
      builder: (context, state) {
        final ingredientWidgets = <Widget>[];

        final allIngredients = state.allIngredients;
        if (allIngredients == null) return const Center(child: CircularProgressIndicator());

        final flatIngredients = allIngredients.values.expand((list) => list).toList();

        for (int index = 0; index < state.recipe.recipeIngredients.length; index++) {
          final ingredient = state.recipe.recipeIngredients[index];
          final initialIngredient = ingredient.name;
          final initialQuantity = ingredient.quantity.toInt().toString();
          final Unit initialUnit = Unit.fromString(ingredient.unit);

          ingredientWidgets.add(
            Dismissible(
              key: ValueKey(ingredient.id),
              onDismissed: (_) => context.read<CreateRecipeBloc>().add(DeleteIngredient(index)),
              background: Container(color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(1,1))],
                  ),
                  child: Row(
                    children: [
                      // ----------------- Ingredient Autocomplete -----------------
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Autocomplete<String>(
                            initialValue: TextEditingValue(text: initialIngredient),
                            optionsBuilder: (textEditingValue) {
                              if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                              return flatIngredients.where((option) =>
                                  option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                            },
                            onSelected: (selection) {
                              String category = allIngredients.entries.firstWhere((entry) => entry.value.contains(selection)).key;
                              context.read<CreateRecipeBloc>().add(
                                IngredientChanged(index: index, ingredient: selection, productCategory: category),
                              );
                            },
                            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                              return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Zutat',
                                  filled: true,
                                  fillColor: Colors.grey.shade200, // immer grau
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                                ),
                                onChanged: (value) {
                                  if (flatIngredients.contains(value)) {
                                    String category = allIngredients.entries
                                        .firstWhere((entry) => entry.value.contains(value))
                                        .key;
                                    context.read<CreateRecipeBloc>().add(
                                      IngredientChanged(index: index, ingredient: value, productCategory: category),
                                    );
                                  } else {
                                    // freier Text → keine Kategorie
                                    context.read<CreateRecipeBloc>().add(
                                      IngredientChanged(index: index, ingredient: value, productCategory: 'OTHER'),
                                    );
                                  }
                                },
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4.0,
                                  borderRadius: BorderRadius.circular(8),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: options.length,
                                    shrinkWrap: true,
                                    itemBuilder: (context, optionIndex) {
                                      final option = options.elementAt(optionIndex);
                                      return ListTile(
                                        title: Text(option),
                                        onTap: () => onSelected(option),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // ----------------- Quantity -----------------
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: (initialQuantity == null ||
                              initialQuantity == 0 ||
                              initialQuantity == '0')
                              ? ''
                              : initialQuantity.toString(),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '0',
                            border: InputBorder.none,
                            filled: true,
                            fillColor: index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                          ),
                          onChanged: (value) {
                            final amount = double.tryParse(value) ?? 0;
                            context.read<CreateRecipeBloc>().add(QuantityChanged(index: index, quantity: amount));
                          },
                        ),
                      ),

                      // ----------------- Unit Picker -----------------
// ----------------- Unit Picker (Dropdown) -----------------
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          isDense: true,
                          isExpanded: true,
                          value: initialUnit.label,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          items: units.map((unit) {
                            return DropdownMenuItem<String>(
                              value: unit.label,
                              child: Text(
                                unit.label,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400)
                              ),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            if (newValue == null) return;
                            context.read<CreateRecipeBloc>().add(
                              UnitChanged(index: index, unit: newValue),
                            );
                          },
                        ),
                      ),




                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => context.read<CreateRecipeBloc>().add(DeleteIngredient(index)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // Add button
        ingredientWidgets.add(
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: IconButton(
              icon: Icon(Icons.add_circle, size: 30, color: Colors.grey.shade600),
              onPressed: () => context.read<CreateRecipeBloc>().add(IngredientAdded()),
            ),
          ),
        );

        return Column(children: ingredientWidgets);
      },
    )
  ];
}

List<Widget> _buildDescriptionFields() {
  return [
    BlocBuilder<CreateRecipeBloc, CreateRecipeState>(
      builder: (context, state) {
        final descWidgets = <Widget>[];
        for (int index = 0; index < state.recipe.cookingInstructions.length; index++) {
          final step = state.recipe.cookingInstructions[index];
          descWidgets.add(
            Dismissible(
              key: ValueKey(index),
              onDismissed: (_) => context.read<CreateRecipeBloc>().add(CookingInstructionDeleted(index)),
              background: Container(color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(1,1))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                      initialValue: step.instruction,
                      decoration: InputDecoration(border: InputBorder.none, hintText: '${index + 1}. Schritt'),
                      onChanged: (value) => context.read<CreateRecipeBloc>().add(
                          CookingInstructionChanged(index: index, cookingInstruction: CookingInstruction(instruction: value, recipeIngredients: []))),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        descWidgets.add(
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: IconButton(
              icon: Icon(Icons.add_circle, size: 30, color: Colors.grey.shade600),
              onPressed: () => context.read<CreateRecipeBloc>().add(CookingInstructionAdded()),
            ),
          ),
        );

        return Column(children: descWidgets);
      },
    )
  ];
}

Widget _saveCreateRecipeChangesButton() {
  return BlocBuilder<CreateRecipeBloc, CreateRecipeState>(
    builder: (context, state) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: state.formStatus is FormSubmitting ? null : () => context.read<CreateRecipeBloc>().add(SaveCreateRecipeChanges()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
          child: state.formStatus is FormSubmitting
              ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
              : const Text('Speichern', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      );
    },
  );
}

void _showImageSourceActionSheet(BuildContext context) {
  bool isImageSourceSelected = false;

  void selectImageSource(ImageSource? imageSource) {
    if (imageSource != null) {
      context.read<CreateRecipeBloc>().add(OpenImagePicker(imageSource: imageSource));
      isImageSourceSelected = true;
    } else {
      if (!isImageSourceSelected) context.read<CreateRecipeBloc>().add(CancelImageSelection());
    }
  }

  void deleteCurrentImage() => context.read<CreateRecipeBloc>().add(CurrentImageDeleted());

  if (Platform.isIOS) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(child: const Text('Camera'), onPressed: () { Navigator.pop(context); selectImageSource(ImageSource.camera); }),
          CupertinoActionSheetAction(child: const Text('Gallery'), onPressed: () { Navigator.pop(context); selectImageSource(ImageSource.gallery); }),
          CupertinoActionSheetAction(isDestructiveAction: true, child: const Text('Delete Current Image'), onPressed: () { Navigator.pop(context); deleteCurrentImage(); }),
        ],
        cancelButton: CupertinoActionSheetAction(child: const Text('Cancel'), onPressed: () { Navigator.pop(context); selectImageSource(null); }),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      builder: (_) => Wrap(
        children: [
          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Camera'), onTap: () { Navigator.pop(context); selectImageSource(ImageSource.camera); }),
          ListTile(leading: const Icon(Icons.photo_album), title: const Text('Gallery'), onTap: () { Navigator.pop(context); selectImageSource(ImageSource.gallery); }),
          ListTile(leading: const Icon(Icons.delete), title: const Text('Delete Current Image'), onTap: () { Navigator.pop(context); deleteCurrentImage(); }),
        ],
      ),
    ).whenComplete(() {
      if (Navigator.of(context).canPop() && !isImageSourceSelected) selectImageSource(null);
    });
  }
}
