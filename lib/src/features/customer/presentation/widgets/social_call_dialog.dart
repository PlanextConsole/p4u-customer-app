import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../data/customer_providers.dart';

class SocialCallDialog extends ConsumerStatefulWidget {
  const SocialCallDialog({required this.conversationId, required this.callType, this.incomingCall, super.key});
  final String conversationId;
  final String callType;
  final Map<String,dynamic>? incomingCall;
  @override ConsumerState<SocialCallDialog> createState()=>_SocialCallDialogState();
}

class _SocialCallDialogState extends ConsumerState<SocialCallDialog> {
  final local=RTCVideoRenderer(),remote=RTCVideoRenderer();
  RTCPeerConnection? peer; MediaStream? stream; Timer? poll; Map<String,dynamic>? call; String error=''; bool busy=false;
  bool get incoming=>widget.incomingCall!=null;
  @override void initState(){super.initState();local.initialize();remote.initialize();call=widget.incomingCall;if(!incoming)Future.microtask(_start);}
  Future<RTCPeerConnection> _peer() async {final p=await createPeerConnection({'iceServers':[{'urls':'stun:stun.l.google.com:19302'}]});stream=await navigator.mediaDevices.getUserMedia({'audio':true,'video':widget.callType=='video'});local.srcObject=stream;for(final track in stream!.getTracks()){await p.addTrack(track,stream!);}p.onTrack=(event){if(event.streams.isNotEmpty&&mounted)setState(()=>remote.srcObject=event.streams.first);};peer=p;return p;}
  Future<void> _start() async {setState(()=>busy=true);try{final p=await _peer();await p.setLocalDescription(await p.createOffer());await Future<void>.delayed(const Duration(milliseconds:1500));final localDescription=await p.getLocalDescription();call=await ref.read(customerRepositoryProvider).startSocialCall(widget.conversationId,widget.callType,offerSdp:localDescription?.sdp);_beginPolling();}catch(e){error='$e';await _cleanup();}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> _accept() async {if(call==null)return;setState(()=>busy=true);try{final p=await _peer();final offer='${call!['offer_sdp']??''}';if(offer.isEmpty)throw Exception('Call offer is missing');await p.setRemoteDescription(RTCSessionDescription(offer,'offer'));await p.setLocalDescription(await p.createAnswer());await Future<void>.delayed(const Duration(milliseconds:1500));final answer=await p.getLocalDescription();call=await ref.read(customerRepositoryProvider).acceptSocialCall('${call!['id']}',answerSdp:answer?.sdp);_beginPolling();}catch(e){error='$e';await _cleanup();}finally{if(mounted)setState(()=>busy=false);}}
  void _beginPolling(){poll?.cancel();poll=Timer.periodic(const Duration(seconds:2),(_)async{if(call==null){return;}try{final next=await ref.read(customerRepositoryProvider).socialCall('${call!['id']}');if(!mounted){return;}call=next;if(!incoming&&next['status']=='accepted'&&'${next['answer_sdp']??''}'.isNotEmpty){final description=await peer?.getRemoteDescription();if(description==null){await peer!.setRemoteDescription(RTCSessionDescription('${next['answer_sdp']}','answer'));}}if(['ended','rejected','missed'].contains('${next['status']}')){await _cleanup();if(mounted){Navigator.pop(context);}}else{setState((){});}}catch(_){}});}
  Future<void> _finish({bool reject=false})async{if(call!=null){try{if(reject){await ref.read(customerRepositoryProvider).rejectSocialCall('${call!['id']}');}else{await ref.read(customerRepositoryProvider).endSocialCall('${call!['id']}');}}catch(_){}}await _cleanup();if(mounted){Navigator.pop(context);}}  Future<void> _cleanup()async{poll?.cancel();for(final track in stream?.getTracks()??<MediaStreamTrack>[]){track.stop();}await stream?.dispose();await peer?.close();peer=null;stream=null;}
  @override void dispose(){poll?.cancel();for(final track in stream?.getTracks()??<MediaStreamTrack>[]){track.stop();}peer?.close();stream?.dispose();local.dispose();remote.dispose();super.dispose();}
  @override Widget build(BuildContext context){final status='${call?['status']??(busy?'connecting':'ringing')}';return Dialog(backgroundColor:Colors.black,child:Padding(padding:const EdgeInsets.all(16),child:Column(mainAxisSize:MainAxisSize.min,children:[Text(incoming&&status=='ringing'?'Incoming ${widget.callType} call':status=='accepted'?'Call connected':'Calling…',style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.bold)),if(widget.callType=='video')Container(margin:const EdgeInsets.only(top:16),height:300,color:Colors.black,child:Stack(children:[RTCVideoView(remote,objectFit:RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),Positioned(right:8,bottom:8,width:90,height:120,child:RTCVideoView(local,mirror:true))])),if(widget.callType=='audio')const Padding(padding:EdgeInsets.all(28),child:Icon(Icons.call_rounded,size:72,color:Colors.white)),if(error.isNotEmpty)Text(error,style:const TextStyle(color:Colors.redAccent)),const SizedBox(height:16),Row(mainAxisAlignment:MainAxisAlignment.center,children:[if(incoming&&status=='ringing')FilledButton(onPressed:busy?null:_accept,child:const Text('Accept')),if(incoming&&status=='ringing')const SizedBox(width:12),FilledButton(style:FilledButton.styleFrom(backgroundColor:Colors.red),onPressed:()=>_finish(reject:incoming&&status=='ringing'),child:Text(incoming&&status=='ringing'?'Decline':'End'))])])));}
}
