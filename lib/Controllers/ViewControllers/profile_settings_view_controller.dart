// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:friendfy/Http/http_service.dart';
import 'package:friendfy/Local/local_db_keys.dart';
import 'package:friendfy/Models/user_model.dart';
import 'package:friendfy/Services/local_service.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:image_picker/image_picker.dart';

import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/main.dart';

class ProfileSettingsViewController extends StateNotifier<ProfileSettingsViewModel>{
  final Ref? ref;
  ProfileSettingsViewController(this.ref):super(ProfileSettingsViewModel(nameChanged: false));
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController birthdateController = TextEditingController();
  TextEditingController genderController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

init(){
  try {
    final user = ref?.read(AllControllers.userController);
    nameController.text = user?.username ?? "";
    emailController.text = user?.email ?? "";
    
    // Doğum tarihini formatla ve controller'a ekle
    if (user?.birthdate != null) {
      final birthdate = user!.birthdate;
      birthdateController.text = '${birthdate.day.toString().padLeft(2, '0')}.${birthdate.month.toString().padLeft(2, '0')}.${birthdate.year}';
    }
    
    // Cinsiyeti formatla ve controller'a ekle
    if (user?.gender != null) {
      final gender = user!.gender;
      switch (gender!.toLowerCase()) {
        case 'male':
          genderController.text = "Erkek"; // Translate edilecek
          break;
        case 'female':
          genderController.text = "Kadın"; // Translate edilecek
          break;
        default:
          genderController.text = "Belirtmeyi tercih etmiyorum"; // Translate edilecek
      }
    } else {
      genderController.text = "Belirtmeyi tercih etmiyorum"; // Translate edilecek
    }
    
    state = state.copyWith(photoURL: user?.photoURL);
  } catch (e) {
    log("⚠️ Error in init: $e");
  }
}

nameChanged(String val){
  try {
    final currentUsername = ref?.read(AllControllers.userController)?.username;
    if (val.trim().isNotEmpty && val.trim() != currentUsername) {
      state = state.copyWith(nameChanged: true);
    } else {
      _checkIfChanged();
    }
  } catch (e) {
    log("⚠️ State update error in nameChanged: $e");
  }
}

void birthdateChanged(DateTime newBirthdate) {
  try {
    final currentBirthdate = ref?.read(AllControllers.userController)?.birthdate;
    if (currentBirthdate == null || 
        newBirthdate.year != currentBirthdate.year ||
        newBirthdate.month != currentBirthdate.month ||
        newBirthdate.day != currentBirthdate.day) {
      state = state.copyWith(
        nameChanged: true,
        birthdate: newBirthdate,
      );
      // Controller'ı güncelle
      birthdateController.text = '${newBirthdate.day.toString().padLeft(2, '0')}.${newBirthdate.month.toString().padLeft(2, '0')}.${newBirthdate.year}';
    } else {
      _checkIfChanged();
    }
  } catch (e) {
    log("⚠️ State update error in birthdateChanged: $e");
  }
}

void genderChanged(String? newGender) {
  try {
    // State'i güncelle (dropdown için gerekli)
    // Null değerini set etmek için setGenderToNull flag'i kullan
    // nameChanged'i burada set etme, _checkIfChanged() ile kontrol edilecek
    state = state.copyWith(
      gender: newGender,
      genderChanged: true,
      setGenderToNull: newGender == null, // Null ise flag true
    );
    
    // Controller'ı güncelle
    if (newGender == null) {
      genderController.text = "Belirtmeyi tercih etmiyorum";
    } else {
      switch (newGender.toLowerCase()) {
        case 'male':
          genderController.text = "Erkek";
          break;
        case 'female':
          genderController.text = "Kadın";
          break;
        default:
          genderController.text = "Belirtmeyi tercih etmiyorum";
      }
    }
    
    // State güncellendikten sonra değişiklik kontrolü yap
    _checkIfChanged();
    
    log("✅ Gender changed to: $newGender");
  } catch (e) {
    log("⚠️ State update error in genderChanged: $e");
  }
}

void _checkIfChanged() {
  try {
    final user = ref?.read(AllControllers.userController);
    final hasNameChanged = nameController.text.trim() != (user?.username ?? "");
    final hasBirthdateChanged = state.birthdate != null && 
        (user?.birthdate == null || 
         state.birthdate!.year != user!.birthdate.year ||
         state.birthdate!.month != user.birthdate.month ||
         state.birthdate!.day != user.birthdate.day);
    
    // Gender değişikliğini kontrol et - null değerleri de doğru şekilde karşılaştır
    final currentGender = state.gender;
    final userGender = user?.gender;
    final hasGenderChanged = currentGender != userGender; // Null-safe karşılaştırma
    
    if (hasNameChanged || hasBirthdateChanged || hasGenderChanged || state.selectedImagePath != null) {
      state = state.copyWith(nameChanged: true);
    } else {
      state = state.copyWith(nameChanged: false);
    }
    
    log("🔍 _checkIfChanged: name=$hasNameChanged, birthdate=$hasBirthdateChanged, gender=$hasGenderChanged (current: $currentGender, user: $userGender), image=${state.selectedImagePath != null}");
  } catch (e) {
    log("⚠️ Error in _checkIfChanged: $e");
  }
}

Future<void> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        state = state.copyWith(selectedImagePath: image.path, nameChanged: true);
        log("Image selected: ${image.path}");
      }
    } catch (e) {
      log("Error picking image: $e");
    }
  }

  Future<void> updateProfile() async {
    if (!state.nameChanged!) return;
    
    // Orijinal user'ı sakla (hata durumunda geri almak için)
    final originalUser = ref?.read(AllControllers.userController);
    if (originalUser == null) return;
    
    // Optimistic update - önce UI'ı güncelle, kullanıcı verilerin kaybolduğunu görmesin
    UserModel optimisticUser = originalUser.copyWith(
      username: nameController.text.trim(),
      birthdate: state.birthdate ?? originalUser.birthdate,
      gender: state.genderChanged == true ? state.gender : originalUser.gender,
      // Fotoğraf CDN'e yüklenene kadar eski URL'i kullan (optimistic update)
    );
    ref?.read(AllControllers.userController.notifier).updateUserModel(optimisticUser);
    
    try {
      state = state.copyWith(isLoading: true);
      
      HttpService httpService = HttpService(ref: ref);
      String? uploadedPhotoURL;
      
      // Eğer yeni fotoğraf seçildiyse, önce CDN'e yükle
      if (state.selectedImagePath != null) {
        uploadedPhotoURL = await _uploadImageToCDN(state.selectedImagePath!);
        // Fotoğraf yüklendikten sonra optimistic update'i güncelle
        if (uploadedPhotoURL != null) {
          optimisticUser = optimisticUser.copyWith(photoURL: uploadedPhotoURL);
          ref?.read(AllControllers.userController.notifier).updateUserModel(optimisticUser);
        }
      }
      
      final body = {
        "userId": ref?.read(AllControllers.userController)?.id,
        "username": nameController.text.trim(),
        if (uploadedPhotoURL != null) "photoURL": uploadedPhotoURL,
        if (state.birthdate != null) "birthdate": "${state.birthdate!.year}-${state.birthdate!.month.toString().padLeft(2, '0')}-${state.birthdate!.day.toString().padLeft(2, '0')}",
        // Gender null olabilir (kullanıcı "belirtmeyi tercih etmiyorum" seçebilir)
        // Gender değiştiyse (null dahil) gönder
        if (state.genderChanged == true) "gender": state.gender,
      };
      
      final response = await httpService.post(
        path: AppConstants.updateProfileURL,
        body: body,
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['user'] != null) {
          // Backend'den gelen güncel kullanıcı bilgilerini güncelle
          UserModel updatedUser = UserModel.fromMap(responseData['user']);
          ref?.read(AllControllers.userController.notifier).updateUserModel(updatedUser);
          
          // Arka planda diğer verileri güncelle (kullanıcı beklemesin)
          Future.microtask(() async {
            try {
              await ref?.read(AllControllers.agentsViewController.notifier).getRecentAgents();
              await ref?.read(AllControllers.agentsViewController.notifier).getAgents();
              await ref?.read(AllControllers.chatViewController.notifier).getConversations();
            } catch (e) {
              log("⚠️ Error updating related data: $e");
            }
          });
          
          log("✅ Profile updated successfully");
        
          // Önce navigation yap, sonra state güncelle (dispose hatası önlemek için)
          navigatorKey.currentState?.pop();
          
          // Navigation sonrası state güncellemesi - dispose olmuş olabilir, o yüzden try-catch
          try {
            state = state.copyWith(isLoading: false, nameChanged: false, selectedImagePath: null, genderChanged: false);
          } catch (e) {
            // Controller dispose olmuş olabilir, bu normal
            log("⚠️ State update skipped (controller disposed after navigation)");
          }
        } else {
          // Hata durumunda optimistic update'i geri al
          ref?.read(AllControllers.userController.notifier).updateUserModel(originalUser);
          try {
            state = state.copyWith(isLoading: false);
          } catch (e) {
            log("⚠️ State update error: $e");
          }
          log("❌ Failed to update profile - invalid response");
        }
      } else {
        // Hata durumunda optimistic update'i geri al
        ref?.read(AllControllers.userController.notifier).updateUserModel(originalUser);
        try {
          state = state.copyWith(isLoading: false);
        } catch (e) {
          log("⚠️ State update error: $e");
        }
        log("❌ Failed to update profile - Status: ${response.statusCode}");
      }
    } catch (e, stackTrace) {
      // Hata durumunda optimistic update'i geri al
      ref?.read(AllControllers.userController.notifier).updateUserModel(originalUser);
      try {
        state = state.copyWith(isLoading: false);
      } catch (stateError) {
        log("⚠️ State update error in catch: $stateError");
      }
      log("❌ Error updating profile: $e");
      log("📍 StackTrace: $stackTrace");
    }
  }

  Future<void> _loadData() async {

    
    try {
            await ref?.read(AllControllers.agentsViewController.notifier).getRecentAgents();
             await ref?.read(AllControllers.agentsViewController.notifier).getAgents();
               await ref?.read(AllControllers.chatViewController.notifier).getConversations();
  
    } catch (e) {
      debugPrint("⚠️ Error loading data in HomeView: $e");
    }
  }



  Future<String?> _uploadImageToCDN(String imagePath) async {
    try {
      final file = File(imagePath);
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
      
      // BunnyCDN'e yükleme (chat.js'deki ses yükleme mantığına benzer)
      final bytes = await file.readAsBytes();
      final cdnURL = "https://storage.bunnycdn.com/fakefriendstorage/profiles/$fileName";
      final publicURL = "https://fakefriend.b-cdn.net/profiles/$fileName";
      
      final response = await HttpService(ref: ref).uploadToCDN(
        url: cdnURL,
        fileBytes: bytes,
        contentType: 'image/jpeg',
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        return publicURL;
      }
      return null;
    } catch (e) {
      log("Error uploading image to CDN: $e");
      return null;
    }
  }

  Future<void> logout() async {
    try {
      // Local storage'dan token'ı sil
      await LocalService.deleteData("authToken");
      
      // Bildirimleri temizle
      ref?.read(AllControllers.notificationsViewController.notifier).clearNotifications();
      
      // User state'ini temizle
      ref?.read(AllControllers.userController.notifier).state = null;
      
      // Login sayfasına yönlendir
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/onboard', (route) => false);
      
      log("User logged out successfully");
    } catch (e) {
      log("Error during logout: $e");
    }
  }

  Future<void> deleteAccount() async {
    try {
      state = state.copyWith(isLoading: true);
    } catch (e) {
      log("⚠️ State update error (controller may be disposed): $e");
      return;
    }
    
    try {
      HttpService httpService = HttpService(ref: ref);
      final userId = ref?.read(AllControllers.userController)?.id;
      
      debugPrint("🗑️ Attempting to delete account with userId: $userId");
      
      if (userId == null) {
        debugPrint("❌ UserId is null, cannot delete account");
        try {
          state = state.copyWith(isLoading: false);
        } catch (e) {
          log("⚠️ State update error: $e");
        }
        return;
      }
      
      final response = await httpService.post(
        path: AppConstants.deleteAccountURL,
        body: {
          "userId": userId,
        }
      );
      
      debugPrint("📡 Delete account response: ${response.statusCode}");
      debugPrint("📦 Response body: ${response.body}");
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          debugPrint("✅ Account deleted successfully from server");
          
          // Local storage'dan token'ı sil
          await LocalService.deleteData(LocalDbKeys.authToken);
          
          // Bildirimleri temizle
          ref?.read(AllControllers.notificationsViewController.notifier).clearNotifications();
          
          // User state'ini temizle
          ref?.read(AllControllers.userController.notifier).state = null;
          
          // Navigation'dan ÖNCE isLoading'i false yap
          try {
            state = state.copyWith(isLoading: false);
          } catch (e) {
            log("⚠️ State update error (controller may be disposed): $e");
          }
          
          // Login sayfasına yönlendir
          try {
            navigatorKey.currentState?.pushNamedAndRemoveUntil('/accountDeletedView', (route) => false);
          } catch (e) {
            log("⚠️ Navigation error: $e");
          }
          
          log("✅ Account deleted and user logged out");
        } else {
          debugPrint("❌ Server returned success=false: ${responseData['msg']}");
          try {
            state = state.copyWith(isLoading: false);
          } catch (e) {
            log("⚠️ State update error: $e");
          }
        }
      } else {
        try {
          state = state.copyWith(isLoading: false);
        } catch (e) {
          log("⚠️ State update error: $e");
        }
        debugPrint("❌ Failed to delete account - Status: ${response.statusCode}");
      }
    } catch (e, stackTrace) {
      try {
        state = state.copyWith(isLoading: false);
      } catch (stateError) {
        log("⚠️ State update error in catch: $stateError");
      }
      debugPrint("❌ Error deleting account: $e");
      debugPrint("📍 StackTrace: $stackTrace");
    }
  }

}


class ProfileSettingsViewModel {
  final bool? nameChanged;
  final bool? isLoading;
  final String? selectedImagePath;
  final String? photoURL;
  final DateTime? birthdate;
  final String? gender;
  final bool? genderChanged; // Gender değişti mi takibi için
  
  ProfileSettingsViewModel({
    this.nameChanged,
    this.isLoading = false,
    this.selectedImagePath,
    this.photoURL,
    this.birthdate,
    this.gender,
    this.genderChanged = false,
  });

  ProfileSettingsViewModel copyWith({
    bool? nameChanged,
    bool? isLoading,
    String? selectedImagePath,
    String? photoURL,
    DateTime? birthdate,
    String? gender,
    bool? genderChanged,
    bool setGenderToNull = false, // Null set etmek için flag
  }) {
    return ProfileSettingsViewModel(
      nameChanged: nameChanged ?? this.nameChanged,
      isLoading: isLoading ?? this.isLoading,
      selectedImagePath: selectedImagePath ?? this.selectedImagePath,
      photoURL: photoURL ?? this.photoURL,
      birthdate: birthdate ?? this.birthdate,
      // setGenderToNull true ise null set et, değilse gender ?? this.gender kullan
      gender: setGenderToNull ? null : (gender ?? this.gender),
      genderChanged: genderChanged ?? this.genderChanged,
    );
  }
}
