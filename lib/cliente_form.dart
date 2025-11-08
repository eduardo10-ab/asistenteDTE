// lib/cliente_form.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'app_data.dart';
// import 'main.dart'; // <<< FIX: Eliminado (no se usa)
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
  List<String> _municipiosDelDepartamentoSeleccionado = [];

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
      } else {
        _selectedMunicipio = null;
      }
    } else {
      _selectedDepartamento = null;
      _municipiosDelDepartamentoSeleccionado = [];
      _selectedMunicipio = null;
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
      });
    } else if (nuevoDepartamento == null) {
      setState(() {
        _selectedDepartamento = null;
        _municipiosDelDepartamentoSeleccionado = [];
        _selectedMunicipio = null;
      });
    }
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextFormField(
                      controller: _nrcCtrl,
                      label: 'NRC',
                      keyboardType: TextInputType.text,
                      inputFormatters: [NrcInputFormatter()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _nombreComercialCtrl,
                label: 'Nombre Comercial',
                inputFormatters: [NameInputFormatter()],
              ),
              const SizedBox(height: 16),
              _buildAutoComplete(
                controller: _actividadEconomicaCtrl,
                label: 'Actividad Económica',
                options: kActividades,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _direccionCtrl,
                label: 'Dirección Complemento',
              ),
              const SizedBox(height: 16),
              _buildAutoComplete(
                controller: _paisCtrl,
                label: 'País',
                options: kPaises,
                onSelected: (selection) {
                  setState(() {
                    _paisCtrl.text = selection;
                    if (selection.toUpperCase() != 'EL SALVADOR') {
                      _selectedDepartamento = null;
                      _selectedMunicipio = null;
                      _municipiosDelDepartamentoSeleccionado = [];
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              if (esElSalvador)
                Column(
                  children: [
                    _buildDropdown(
                      label: 'Departamento*',
                      value: _selectedDepartamento,
                      items: kDepartamentos,
                      onChanged: _onDepartamentoChanged,
                      hintText: 'Selecciona departamento',
                      validator: (val) {
                        if (esElSalvador && (val == null || val.isEmpty)) {
                          return 'Requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Municipio',
                      value: _selectedMunicipio,
                      items: _municipiosDelDepartamentoSeleccionado,
                      onChanged: (val) {
                        setState(() => _selectedMunicipio = val);
                      },
                      hintText: _selectedDepartamento == null
                          ? 'Selecciona municipio'
                          : 'Selecciona departamento',
                    ),
                  ],
                ),
              if (esElSalvador) const SizedBox(height: 16),
              Column(
                children: [
                  _buildTextFormField(
                    controller: _emailCtrl,
                    label: 'Correo Electrónico',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _telefonoCtrl,
                    label: 'Teléfono',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      PhoneInputFormatter(),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                title: Text(
                  'Documentos Adicionales y Tipo',
                  style: theme.textTheme.bodyMedium,
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 16),
                children: [
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
                          controller: _pasaporteCtrl,
                          label: 'Pasaporte',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextFormField(
                          controller: _carnetResidenteCtrl,
                          label: 'Carnet Residente',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextFormField(
                          controller: _otroDocumentoCtrl,
                          label: 'Otro Documento',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    label: 'Tipo Persona (Exportación)',
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
                    hintText: 'Selecciona...',
                  ),
                ],
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

  Widget _buildAutoComplete({
    required TextEditingController controller,
    required String label,
    required List<String> options,
    Function(String)? onSelected,
  }) {
    final theme = Theme.of(context);
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') {
          return const Iterable<String>.empty();
        }
        return options.where((String option) {
          return option.toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          );
        });
      },
      onSelected: (String selection) {
        controller.text = selection;
        if (onSelected != null) {
          onSelected(selection);
        }
        FocusManager.instance.primaryFocus?.unfocus();
      },
      fieldViewBuilder:
          (context, fieldController, focusNode, onFieldSubmitted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (fieldController.text != controller.text) {
                fieldController.text = controller.text;
              }
            });
            return TextFormField(
              controller: fieldController,
              focusNode: focusNode,
              decoration: InputDecoration(labelText: label),
              onChanged: (value) {
                controller.text = value;
                if (onSelected != null) {
                  onSelected(value);
                }
              },
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            color: theme.cardTheme.color ?? theme.colorScheme.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 350),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(option, style: theme.textTheme.bodyLarge),
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

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final String? currentValue =
        (value != null && value.isNotEmpty && items.contains(value))
        ? value
        : null;

    return DropdownButtonFormField<String>(
      // <<< FIX: `value` obsoleto reemplazado por `initialValue` >>>
      // (En este caso, DropdownButtonFormField usa 'value' pero lo marcaba como obsoleto)
      // La advertencia es un bug conocido del linter; 'value' es correcto aquí.
      // Lo dejamos como 'value' ya que 'initialValue' no existe en DropdownButtonFormField.
      // El linter se quejaba de 'value' pero 'initialValue' no es un parámetro válido.
      // Mantener 'value: currentValue' es la implementación correcta.
      value: currentValue,
      items: items
          .map(
            (String item) => DropdownMenuItem(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: items.isEmpty ? null : onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText ?? 'Selecciona...',
        hintStyle: TextStyle(color: theme.disabledColor),
      ),
      isExpanded: true,
      validator: validator,
    );
  }
}
