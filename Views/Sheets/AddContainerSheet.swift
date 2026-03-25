//
//  AddContainerSheet.swift
//  URUOI
//
//  Created by USER on 2026/01/02.
//

import SwiftUI
import SwiftData

struct AddContainerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var containerName: String = ""
    @State private var emptyWeight: String = ""
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @FocusState private var isInputFocused: Bool
    let viewModel: SettingsViewModel
    let modelContext: ModelContext
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.backgroundGray
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // 器の名前セクション
                            Text("器の名前")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("器の名前", text: $containerName)
                                    .focused($isInputFocused)
                                    .customTextFieldStyle()
                                Text("※20文字以内")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 12)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            
                            // 空重量セクション
                            Text("空重量")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("空重量 (g) - 任意", text: $emptyWeight)
                                    .keyboardType(.decimalPad)
                                    .focused($isInputFocused)
                                    .monospacedDigit()
                                    .customTextFieldStyle()
                                Text("空重量を入力しない場合は0gとして登録されます")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 12)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }
                    .scrollContentBackground(.hidden)
                    .padding(.bottom, 80)
                }
                
                // 画面下部固定の追加ボタン
                Button {
                    addContainer()
                } label: {
                    Text("追加する")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(containerName.isEmpty ? Color.disabledButtonBackground : Color.appMain)
                        .cornerRadius(.buttonCornerRadius)
                }
                .disabled(containerName.isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.backgroundGray.opacity(0), Color.backgroundGray]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                    .offset(y: -80)
                )
            }
            .navigationTitle("器を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .alert("入力エラー", isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
        .keyboardToolbar(focus: $isInputFocused)
    }
    
    private func addContainer() {
        // 1. 名前のバリデーション
        if let nameError = InputValidator.validateName(containerName) {
            validationMessage = nameError
            showingValidationAlert = true
            return
        }
        
        // 2. 重量のバリデーション
        let weight = emptyWeight.isEmpty ? 0.0 : (Double(emptyWeight) ?? 0.0)
        if let weightError = InputValidator.validateWeight(weight) {
            validationMessage = weightError
            showingValidationAlert = true
            return
        }
        
        // 3. バリデーション成功 - 保存処理
        viewModel.addContainer(
            name: containerName.trimmingCharacters(in: .whitespacesAndNewlines),
            emptyWeight: weight,
            modelContext: modelContext
        )
        dismiss()
    }
}

