// lib/cliente_form.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'app_data.dart';
import 'distritos_data.dart';
import 'input_formatters.dart';

class ClienteForm extends StatefulWidget {
  final Cliente? clienteInicial;
  final Function(Cliente) onSave;
  final VoidCallback onCancel;

  const ClienteForm({
    super.key,
    this.clienteInicial,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<ClienteForm> createState() => _ClienteFormState();
}

class _ClienteFormState extends State<ClienteForm> {
  final _formKey = GlobalKey<FormState>();
  late Cliente _cliente;
  bool _isEditing = false;
  String? _selectedDepartamento;
  String? _selectedMunicipio;
  String? _selectedDistrito;
  List<String> _municipiosDelDepartamentoSeleccionado = [];
  List<Distrito> _distritosDisponibles = [];

  // Controladores
  final _nombreClienteCtrl = TextEditingController();
  final _nitCtrl = TextEditingController();
  final _nrcCtrl = TextEditingController();
  final _duiCtrl = TextEditingController();
  final _pasaporteCtrl = TextEditingController();
  final _carnetResidenteCtrl = TextEditingController();
  final _otroDocumentoCtrl = TextEditingController();
  final _nombreComercialCtrl = TextEditingController();
  final _actividadEconomicaCtrl = TextEditingController();
  final _paisCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isEditing = widget.clienteInicial != null;
    _cliente = widget.clienteInicial ?? Cliente(id: '');
    // Cargar datos
    _nombreClienteCtrl.text = _cliente.nombreCliente;
    _nitCtrl.text = _cliente.nit;
    _nrcCtrl.text = _cliente.nrc;
    _duiCtrl.text = _cliente.dui;
    _pasaporteCtrl.text = _cliente.pasaporte;
    _carnetResidenteCtrl.text = _cliente.carnetResidente;
    _otroDocumentoCtrl.text = _cliente.otroDocumento;
    _nombreComercialCtrl.text = _cliente.nombreComercial;
    _actividadEconomicaCtrl.text = _cliente.actividadEconomica;

    _paisCtrl.text = _cliente.pais.isEmpty ? 'EL SALVADOR' : _cliente.pais;

    _direccionCtrl.text = _cliente.direccion;
    _emailCtrl.text = _cliente.email;
    _telefonoCtrl.text = _cliente.telefono;

    if (_cliente.departamento.isNotEmpty &&
        kDepartamentos.contains(_cliente.departamento)) {
      _selectedDepartamento = _cliente.departamento;
      _municipiosDelDepartamentoSeleccionado =
          kDepartamentosMunicipios[_selectedDepartamento] ?? [];
      if (_cliente.municipio.isNotEmpty &&
          _municipiosDelDepartamentoSeleccionado.contains(_cliente.municipio)) {
        _selectedMunicipio = _cliente.municipio;

        // Cargar distritos disponibles
        _distritosDisponibles = getDistritosPorMunicipioYDepartamento(
          _selectedMunicipio!,
          _selectedDepartamento!,
        );

        // Cargar el distrito si existe
        if (_cliente.distrito.isNotEmpty) {
          _selectedDistrito = _cliente.distrito;
        }
      } else {
        _selectedMunicipio = null;
        _selectedDistrito = null;
        _distritosDisponibles = [];
      }
    } else {
      _selectedDepartamento = null;
      _municipiosDelDepartamentoSeleccionado = [];
      _selectedMunicipio = null;
      _selectedDistrito = null;
      _distritosDisponibles = [];
    }

    _nitCtrl.text = NitInputFormatter()
        .formatEditUpdate(TextEditingValue.empty, _nitCtrl.value)
        .text;
    _nrcCtrl.text = NrcInputFormatter()
        .formatEditUpdate(TextEditingValue.empty, _nrcCtrl.value)
        .text;
    _duiCtrl.text = DuiInputFormatter()
        .formatEditUpdate(TextEditingValue.empty, _duiCtrl.value)
        .text;
    _telefonoCtrl.text = PhoneInputFormatter()
        .formatEditUpdate(TextEditingValue.empty, _telefonoCtrl.value)
        .text;
  }

  @override
  void dispose() {
    _nombreClienteCtrl.dispose();
    _nitCtrl.dispose();
    _nrcCtrl.dispose();
    _duiCtrl.dispose();
    _pasaporteCtrl.dispose();
    _carnetResidenteCtrl.dispose();
    _otroDocumentoCtrl.dispose();
    _nombreComercialCtrl.dispose();
    _actividadEconomicaCtrl.dispose();
    _paisCtrl.dispose();
    _direccionCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  void _guardar() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if ((_paisCtrl.text.toUpperCase() == 'EL SALVADOR' ||
            _paisCtrl.text.isEmpty) &&
        _selectedDepartamento == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecciona un departamento.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    _formKey.currentState!.save();
    final clienteActualizado = Cliente(
      id: _cliente.id,
      nombreCliente: _nombreClienteCtrl.text,
      nit: _nitCtrl.text,
      nrc: _nrcCtrl.text,
      tipoPersona: _cliente.tipoPersona,
      pais: _paisCtrl.text,
      dui: _duiCtrl.text,
      pasaporte: _pasaporteCtrl.text,
      carnetResidente: _carnetResidenteCtrl.text,
      otroDocumento: _otroDocumentoCtrl.text,
      nombreComercial: _nombreComercialCtrl.text,
      actividadEconomica: _actividadEconomicaCtrl.text,
      departamento: _selectedDepartamento ?? '',
      municipio: _selectedMunicipio ?? '',
      distrito: _selectedDistrito ?? '',
      direccion: _direccionCtrl.text,
      email: _emailCtrl.text,
      telefono: _telefonoCtrl.text,
    );
    widget.onSave(clienteActualizado);
  }

  void _onDepartamentoChanged(String? nuevoDepartamento) {
    if (nuevoDepartamento != null &&
        nuevoDepartamento != _selectedDepartamento) {
      setState(() {
        _selectedDepartamento = nuevoDepartamento;
        _municipiosDelDepartamentoSeleccionado =
            kDepartamentosMunicipios[nuevoDepartamento] ?? [];
        _selectedMunicipio = null;
        _selectedDistrito = null;
        _distritosDisponibles = [];
      });
    } else if (nuevoDepartamento == null) {
      setState(() {
        _selectedDepartamento = null;
        _municipiosDelDepartamentoSeleccionado = [];
        _selectedMunicipio = null;
        _selectedDistrito = null;
        _distritosDisponibles = [];
      });
    }
  }

  void _onMunicipioChanged(String? nuevoMunicipio) {
    setState(() {
      _selectedMunicipio = nuevoMunicipio;
      _selectedDistrito = null;

      // Actualizar distritos disponibles según el municipio y departamento seleccionados
      if (nuevoMunicipio != null && _selectedDepartamento != null) {
        _distritosDisponibles = getDistritosPorMunicipioYDepartamento(
          nuevoMunicipio,
          _selectedDepartamento!,
        );
      } else {
        _distritosDisponibles = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool esElSalvador =
        (_paisCtrl.text.toUpperCase() == 'EL SALVADOR' ||
        _paisCtrl.text.isEmpty);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isEditing ? 'Editar Cliente' : 'Agregar Nuevo Cliente',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              // 1. Nombre
              _buildTextFormField(
                controller: _nombreClienteCtrl,
                label: 'Nombre del Cliente*',
                inputFormatters: [NameInputFormatter()],
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Campo requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 2 y 3. DUI y NIT en la misma fila (50% cada uno)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTextFormField(
                      controller: _duiCtrl,
                      label: 'DUI',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        DuiInputFormatter(),
                      ],
                      validator: (value) {
                        if (value != null &&
                            value.isNotEmpty &&
                            value.length < 10) {
                          return 'DUI incompleto';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextFormField(
                      controller: _nitCtrl,
                      label: 'NIT',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        NitInputFormatter(),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return null;
                        }
                        if (value.length < 17) {
                          return 'NIT debe tener 14 dígitos';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 4. NRC
              _buildTextFormField(
                controller: _nrcCtrl,
                label: 'NRC',
                keyboardType: TextInputType.number,
                inputFormatters: [NrcInputFormatter()],
              ),
              const SizedBox(height: 16),
              // 5. Actividad Económica
              _buildAutocomplete(
                label: 'Actividad Económica',
                controller: _actividadEconomicaCtrl,
                options: kActividades,
                hintText: 'Escribe para buscar...',
              ),
              const SizedBox(height: 16),
              // 6. Departamento
              if (esElSalvador)
                _buildDropdown(
                  label: 'Departamento*',
                  value: _selectedDepartamento,
                  items: kDepartamentos,
                  onChanged: _onDepartamentoChanged,
                  hintText: 'Selecciona departamento',
                  readOnly: true,
                  validator: (val) {
                    if (esElSalvador && (val == null || val.isEmpty)) {
                      return 'Requerido';
                    }
                    return null;
                  },
                ),
              if (esElSalvador) const SizedBox(height: 16),
              // 7. Municipio
              if (esElSalvador)
                _buildDropdown(
                  label: 'Municipio',
                  value: _selectedMunicipio,
                  items: _municipiosDelDepartamentoSeleccionado,
                  onChanged: _onMunicipioChanged,
                  hintText: _selectedDepartamento == null
                      ? 'Primero selecciona departamento'
                      : 'Selecciona municipio',
                  readOnly: true,
                ),
              if (esElSalvador) const SizedBox(height: 16),
              // 8. Distrito (dropdown con opciones filtradas)
              if (esElSalvador && _distritosDisponibles.isNotEmpty)
                _buildDropdown(
                  label: 'Distrito',
                  value: _selectedDistrito,
                  items: _distritosDisponibles
                      .map((d) => d.displayName)
                      .toList(),
                  onChanged: (val) {
                    setState(() => _selectedDistrito = val);
                  },
                  hintText: 'Selecciona distrito',
                  readOnly: true,
                ),
              if (esElSalvador && _distritosDisponibles.isNotEmpty)
                const SizedBox(height: 16),
              // 9. Dirección de complemento
              _buildTextFormField(
                controller: _direccionCtrl,
                label: 'Dirección de Complemento',
              ),
              const SizedBox(height: 16),
              // 10. Correo
              _buildTextFormField(
                controller: _emailCtrl,
                label: 'Correo Electrónico',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              // 11. Celular
              _buildTextFormField(
                controller: _telefonoCtrl,
                label: 'Celular',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  PhoneInputFormatter(),
                ],
              ),
              const SizedBox(height: 16),
              // 12. Pasaporte
              _buildTextFormField(
                controller: _pasaporteCtrl,
                label: 'Pasaporte',
              ),
              const SizedBox(height: 16),
              // 13. Carnet
              _buildTextFormField(
                controller: _carnetResidenteCtrl,
                label: 'Carnet Residente',
              ),
              const SizedBox(height: 16),
              // 14. Otro doc
              _buildTextFormField(
                controller: _otroDocumentoCtrl,
                label: 'Otro Documento',
              ),
              const SizedBox(height: 16),
              // 15. Tipo de persona
              _buildDropdown(
                label: 'Tipo de Persona',
                value: _cliente.tipoPersona.isEmpty
                    ? null
                    : _cliente.tipoPersona,
                items: ['NATURAL', 'JURÍDICA'],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _cliente.tipoPersona = val;
                    });
                  }
                },
                hintText: 'Selecciona tipo de persona',
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _guardar,
                    child: const Text('Guardar Cliente'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widgets Helpers ---

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    String? hintText,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    final theme = Theme.of(context);
    final controller = TextEditingController(text: value ?? '');

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: value ?? ''),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return items;
        }
        final searchText = textEditingValue.text.toLowerCase();
        final results = items.where((String option) {
          return option.toLowerCase().contains(searchText);
        });
        return results.take(50);
      },
      onSelected: (String selection) {
        controller.text = selection;
        onChanged(selection);
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController fieldController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        if (fieldController.text.isEmpty && value != null && value.isNotEmpty) {
          fieldController.text = value;
        }

        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          readOnly: readOnly,
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText ?? 'Escribe para buscar...',
            hintStyle: TextStyle(color: theme.disabledColor),
            suffixIcon: fieldController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      fieldController.clear();
                      controller.clear();
                      onChanged(null);
                    },
                  )
                : const Icon(Icons.arrow_drop_down, size: 20),
          ),
          validator: validator,
          onChanged: (val) {
            controller.text = val;
            if (val.isEmpty) {
              onChanged(null);
            }
          },
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<String> onSelected,
        Iterable<String> options,
      ) {
        final optionsList = options.toList();
        final itemHeight = 48.0;
        final totalHeight = (optionsList.length * itemHeight).clamp(150.0, 400.0);
        
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8.0),
            color: theme.cardColor,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 150,
                maxHeight: totalHeight,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                shrinkWrap: true,
                itemCount: optionsList.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = optionsList[index];
                  return InkWell(
                    onTap: () {
                      onSelected(option);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: theme.dividerColor,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Text(
                        option,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAutocomplete({
    required String label,
    required TextEditingController controller,
    required List<String> options,
    String? hintText,
  }) {
    final theme = Theme.of(context);

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        if (textEditingValue.text.length < 2) {
          return const Iterable<String>.empty();
        }
        final searchText = textEditingValue.text.toLowerCase();
        final results = options.where((String option) {
          return option.toLowerCase().contains(searchText);
        });
        // Limitar a 50 resultados para evitar lag
        return results.take(50);
      },
      onSelected: (String selection) {
        controller.text = selection;
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController fieldController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        // Sincronizar el texto inicial
        if (fieldController.text.isEmpty && controller.text.isNotEmpty) {
          fieldController.text = controller.text;
        }

        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText ?? 'Escribe para buscar...',
            hintStyle: TextStyle(color: theme.disabledColor),
            suffixIcon: fieldController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      fieldController.clear();
                      controller.clear();
                    },
                  )
                : const Icon(Icons.search, size: 20),
          ),
          onChanged: (value) {
            controller.text = value;
          },
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<String> onSelected,
        Iterable<String> options,
      ) {
        final optionsList = options.toList();
        final itemHeight = 48.0;
        final totalHeight = (optionsList.length * itemHeight).clamp(150.0, 400.0);
        
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8.0),
            color: theme.cardColor,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 150,
                maxHeight: totalHeight,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                shrinkWrap: true,
                itemCount: optionsList.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = optionsList[index];
                  return InkWell(
                    onTap: () {
                      onSelected(option);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: theme.dividerColor,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Text(
                        option,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
