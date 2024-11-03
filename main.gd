extends XROrigin3D


var prevl = null
var prevr = null

const move_btn = "primary_click"

var isl = false
var isr = false

func _process(delta: float) -> void:
	var l = $XRController3D_l.position if isl and $XRController3D_l.get_has_tracking_data() else null
	var r = $XRController3D_r.position if isr and $XRController3D_r.get_has_tracking_data() else null
	
	match [prevl and l, prevr and r]:
		[true, true]:
			$views.position += l-prevl
			var prev_vec:Vector3 = prevl-prevr
			var curr_vec:Vector3 = l-r
			var s = curr_vec.length()/prev_vec.length()
			$views.scale *= s
		[true, false]:
			$views.position += l-prevl
		[false, true]:
			$views.position += r-prevr
		[false, false]:
			pass
	
	prevl = l
	prevr = r
	
var webxr_interface: WebXRInterface
var vr_supported = false

func _webxr_selectstart(id):
	match webxr_interface.get_input_source_tracker(id).hand:
		1:
			isl=true
		2:
			isr=true

func _webxr_selectend(id):
	match webxr_interface.get_input_source_tracker(id).hand:
		1:
			isl=false
		2:
			isr=false

func _ready():
	# We assume this node has a button as a child.
	# This button is for the user to consent to entering immersive VR mode.
	$Button.pressed.connect(self._on_button_pressed)

	webxr_interface = XRServer.find_interface("WebXR")
	if webxr_interface:
		# WebXR uses a lot of asynchronous callbacks, so we connect to various
		# signals in order to receive them.
		webxr_interface.session_supported.connect(self._webxr_session_supported)
		webxr_interface.session_started.connect(self._webxr_session_started)
		webxr_interface.session_ended.connect(self._webxr_session_ended)
		webxr_interface.session_failed.connect(self._webxr_session_failed)
		webxr_interface.selectstart.connect(self._webxr_selectstart)
		webxr_interface.selectend.connect(self._webxr_selectend)

		# This returns immediately - our _webxr_session_supported() method
		# (which we connected to the "session_supported" signal above) will
		# be called sometime later to let us know if it's supported or not.
		webxr_interface.is_session_supported("immersive-vr")

func _webxr_session_supported(session_mode, supported):
	if session_mode == 'immersive-vr':
		vr_supported = supported

func _on_button_pressed():
	if not vr_supported:
		OS.alert("Your browser doesn't support VR")
		return

	# We want an immersive VR session, as opposed to AR ('immersive-ar') or a
	# simple 3DoF viewer ('viewer').
	webxr_interface.session_mode = 'immersive-vr'
	# 'bounded-floor' is room scale, 'local-floor' is a standing or sitting
	# experience (it puts you 1.6m above the ground if you have 3DoF headset),
	# whereas as 'local' puts you down at the XROrigin.
	# This list means it'll first try to request 'bounded-floor', then
	# fallback on 'local-floor' and ultimately 'local', if nothing else is
	# supported.
	webxr_interface.requested_reference_space_types = 'local-floor, local'
	# In order to use 'local-floor' or 'bounded-floor' we must also
	# mark the features as required or optional. By including 'hand-tracking'
	# as an optional feature, it will be enabled if supported.
	webxr_interface.required_features = 'local-floor'
	webxr_interface.optional_features = 'hand-tracking'

	# This will return false if we're unable to even request the session,
	# however, it can still fail asynchronously later in the process, so we
	# only know if it's really succeeded or failed when our
	# _webxr_session_started() or _webxr_session_failed() methods are called.
	if not webxr_interface.initialize():
		OS.alert("Failed to initialize")
		return

func _webxr_session_started():
	$Button.visible = false
	# This tells Godot to start rendering to the headset.
	get_viewport().use_xr = true
	# This will be the reference space type you ultimately got, out of the
	# types that you requested above. This is useful if you want the game to
	# work a little differently in 'bounded-floor' versus 'local-floor'.
	print("Reference space type: ", webxr_interface.reference_space_type)
	# This will be the list of features that were successfully enabled
	# (except on browsers that don't support this property).
	print("Enabled features: ", webxr_interface.enabled_features)

func _webxr_session_ended():
	$Button.visible = true
	# If the user exits immersive mode, then we tell Godot to render to the web
	# page again.
	get_viewport().use_xr = false

func _webxr_session_failed(message):
	OS.alert("Failed to initialize: " + message)
