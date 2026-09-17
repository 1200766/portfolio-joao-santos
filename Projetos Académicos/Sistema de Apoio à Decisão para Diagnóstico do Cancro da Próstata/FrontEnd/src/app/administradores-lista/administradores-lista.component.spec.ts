import { ComponentFixture, TestBed } from '@angular/core/testing';

import { AdministradoresListaComponent } from './administradores-lista.component';

describe('AdministradoresListaComponent', () => {
  let component: AdministradoresListaComponent;
  let fixture: ComponentFixture<AdministradoresListaComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [ AdministradoresListaComponent ]
    })
    .compileComponents();

    fixture = TestBed.createComponent(AdministradoresListaComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
